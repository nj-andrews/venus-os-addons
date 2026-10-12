import json
import os
import sys
import subprocess
import argparse
import base64
import shutil
import xml.etree.ElementTree as ET
import re

def collect_filenames(directories, suffix):
		# Accept either a single string/path or a list of paths
		if isinstance(directories, (str, os.PathLike)):
			directories = [directories]

		files = []
		for directory in directories:
			# Skip paths that don't exist or aren't directories
			if not os.path.isdir(directory):
				continue
			for filename in os.listdir(directory):
				if filename.endswith(suffix):
					full_path = os.path.join(directory, filename)
					normalized_path = os.path.normpath(full_path)
					files.append(filename if normalized_path == '.' else normalized_path)
		return files

def run_lupdate(qmlFiles, tsFiles, name):
		cmd = ['lupdate']
		cmd.extend(qmlFiles)
		if len(tsFiles) > 0:
				cmd.extend(['-ts'])
				for tsFile in tsFiles:
						cmd.extend([tsFile])
		else:
				defaultTsName = os.path.join("translations", name + "_en.ts")
				cmd.extend(['-ts', defaultTsName])
		try:
				result = subprocess.run(cmd, capture_output=True, text=True, check=True)
				if result.stdout:
						print("    lupdate output:", result.stdout)
				if result.stderr:
						print("    lupdate stderr:", result.stderr)
		except subprocess.CalledProcessError as e:
				print(f"    lupdate returncode: {e.returncode}")
				print("    lupdate error:", e.stderr, file=sys.stderr)

def run_lrelease(tsFiles, name):
		if len(tsFiles) == 0:
				tsFiles.append(os.path.join("translations", name + "_en.ts"))
		for filename in tsFiles:
				qmFile = os.path.basename(filename)[:-2] + "qm"
				cmd = ['lrelease']
				cmd.extend([filename])
				cmd.extend(['-idbased'])
				cmd.extend(['-qm', qmFile])
				try:
						result = subprocess.run(cmd, capture_output=True, text=True, check=True)
						if result.stdout:
								print("    lrelease output:", result.stdout)
						if result.stderr:
								print("    lrelease stderr:", result.stderr)
				except subprocess.CalledProcessError as e:
						print(f"    lrelease returncode: {e.returncode}")
						print("    lrelease error:", e.stderr, file=sys.stderr)

def write_qrc(qmlFiles, qmFiles, imageFiles, name):
		allFiles = qmlFiles + qmFiles + imageFiles
		contents = "<RCC>\n<qresource prefix=\"/" + name + "\">\n"

		device_delegates_contents = "<qresource prefix=\"/qt/qml/Victron/VenusOS/pages/settings/devicelist/delegates\">\n"
		has_device_delegates = False

		for filename in allFiles:
				if filename.endswith(".qml") and filename.startswith("DeviceListDelegate_") :
					device_delegates_contents += f"<file>{filename}</file>\n"
					has_device_delegates = True
					print(f"    write_qrc adding delegate: {filename}")
					continue
				else:
					contents += "<file>" + filename + "</file>\n"

		contents += "</qresource>\n"
		if has_device_delegates:
			contents += device_delegates_contents
			contents += "</qresource>\n"

		contents += "</RCC>\n"
		try:
				filename = "" + name + ".qrc"
				with open(filename, 'w') as file:
						file.write(contents)
		except IOError as e:
				print(f"    Error writing to file: {e}", e.stderr, file=sys.stderr)

def _minify_qml_text(relative_path):
    """
    Safely minifies QML text by stripping comments, trimming padding,
    removing empty lines, and pulling lonely closing braces up onto the previous line.
    """
    with open(relative_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 1. Strip multi-line block comments /* ... */
    content = re.sub(r'/\*[\s\S]*?\*/', '', content)

    # 2. Strip single-line comments // (ignoring occurrences inside URLs like http://)
    content = re.sub(r'(?<!:)\/\/.*', '', content)

    cleaned_lines = []

    # 3. Clean line padding and remove empty lines
    for line in content.splitlines():
        stripped_line = line.strip()
        if stripped_line:
            cleaned_lines.append(stripped_line)

    # Rejoin the lines to apply structural newline collapsing
    collapsed_content = "\n".join(cleaned_lines)

    # 4. Safe structural collapsing
    # Pull opening braces up: Item\n{ -> Item {
    collapsed_content = re.sub(r'\n\s*\{', ' {', collapsed_content)

    # Pull the next line up when the current line ends with an opening brace:
    # Item {\n    width: 100 -> Item { width: 100
    collapsed_content = re.sub(r'\{\s*\n\s*', '{ ', collapsed_content)

    # Pull the next line up when it starts with a ternary continuation:
    # cond\n    ? valueA\n    : valueB -> cond ? valueA : valueB
    collapsed_content = re.sub(r'\n\s*([?:])\s*', r' \1 ', collapsed_content)

    # Pull the next line up when it starts with +, preserving spaces around the operator.
    collapsed_content = re.sub(r'\n\s*\+\s*', ' + ', collapsed_content)

    # Pull chained member calls up without inserting spaces before the dot.
    collapsed_content = re.sub(r'(?<=\S)\n\s*\.\s*', '.', collapsed_content)

    # Pull closing group tokens up without introducing stray spaces before them.
    collapsed_content = re.sub(r'\n\s*\)', ')', collapsed_content)

    # Pull lonely closing braces up: Statement\n} -> Statement}
    # This removes the newline character entirely before a closing brace
    collapsed_content = re.sub(r'\n\s*\}', '}', collapsed_content)

    optimized_text_path = relative_path + ".tmp"
    with open(optimized_text_path, "w", encoding="utf-8") as f:
        f.write(collapsed_content)

    return optimized_text_path

def _precompile_qml_resources(qrc_file, temp_qrc_file, qmlcachegen_path, pre_compile, minify):
		"""
		Parses a .qrc file, runs whitespace stripping, and optionally
		compiles files into .qmlc bytecode. Writes a temporary modified .qrc file.
		Returns a list of generated artifact files to clean up later.
		"""
		try:
				tree = ET.parse(qrc_file)
				root = tree.getroot()
		except ET.ParseError as e:
				print(f"Error parsing {qrc_file}: {e}", file=sys.stderr)
				return None

		# Track files found in the QRC structure
		qml_files_to_process = []
		for qresource in root.findall('qresource'):
			for index, file_elem in enumerate(list(qresource)):
					#for file_elem in qresource.findall('file'):
					relative_path = file_elem.text
					if relative_path and relative_path.endswith('.qml'):
							qml_files_to_process.append((file_elem, relative_path, index))

		if not qml_files_to_process:
				return []

		generated_artifacts = []

		print("qmlcachegen_path=" + qmlcachegen_path)

		for file_elem, relative_path, index in qml_files_to_process:
				if not os.path.exists(relative_path):
						print(f"Warning: File {relative_path} not found on disk, skipping optimization.")
						continue

				# Invoke the separate whitespace stripping routine
				if not pre_compile and minify:
					#print(f"    Stripped leading lines/whitespace from text file: {relative_path}")
					optimized_text_path = _minify_qml_text(relative_path)
					generated_artifacts.append(optimized_text_path)
					file_elem.set('alias', relative_path)
					file_elem.text = optimized_text_path
				else:
					optimized_text_path = relative_path

				final_resource_path = optimized_text_path

				# Handle binary pre-compilation if requested
				if pre_compile:
						qmlc_path = relative_path + 'c'  # e.g., main.qml -> main.qmlc

						cache_cmd = [qmlcachegen_path, '-o', qmlc_path, optimized_text_path]
						#cache_cmd = [qmlcachegen_path, "--only-bytecode", qmlc_path]
						print(f"    Precompiling QML: {relative_path} -> {qmlc_path}")

						try:
								subprocess.run(cache_cmd, check=True, capture_output=True, text=True)
								generated_artifacts.append(qmlc_path)
								final_resource_path = qmlc_path
						except subprocess.CalledProcessError as e:
								print(f"    qmlcachegen error on {relative_path}: {e.stderr}", file=sys.stderr)
								# Cleanup intermediate files before failing
								for f in generated_artifacts:
										if os.path.exists(f): os.remove(f)
								return None

						# 2. Add empty="true" to the original .qml node to strip the source code
						file_elem.set('empty', 'true')

						# 4. Create the new XML SubElement for the .qmlc file
						qmlc_elem = ET.Element('file')
						qmlc_elem.text = final_resource_path
						#qmlc_elem.set('alias', os.path.basename(relative_path if not pre_compile else relative_path + 'c'))
						# 5. Insert it exactly one position AFTER the current .qml file node
						qresource.insert(index + 1, qmlc_elem)

		# Write the modified tree structure out to the temporary .qrc file path
		tree.write(temp_qrc_file, encoding="utf-8", xml_declaration=True)

		return generated_artifacts


def run_rcc(name, pre_compile=False, minify=False):
		# 1. Resolve paths for rcc and qmlcachegen
		if shutil.which('rcc'):
				rccPath = 'rcc'
				qmlcachegenPath = shutil.which('qmlcachegen') or 'qmlcachegen'
		else:
				lreleasePath = shutil.which('lrelease')
				if not lreleasePath:
						print("Error: Could not find rcc or lrelease to resolve Qt toolchain.", file=sys.stderr)
						return
				rccPath = lreleasePath.replace('/usr/bin/lrelease', '/usr/libexec/rcc')
				qmlcachegenPath = lreleasePath.replace('/usr/bin/lrelease', '/usr/libexec/qmlcachegen')

		qrcFile = f"{name}.qrc"
		rccFile = f"{name}.rcc"
		tempQrcFile = f"{name}_compiled.qrc"

		targetQrcFile = qrcFile
		generated_artifacts = []

		if not os.path.exists(qrcFile):
				print(f"Error: {qrcFile} not found.", file=sys.stderr)
				return

		# 2. Invoke the optimization/compilation workflow
		generated_artifacts = _precompile_qml_resources(
			qrcFile,
			tempQrcFile,
			qmlcachegenPath,
			pre_compile,
			minify)

		if generated_artifacts is None:
				print("    Aborting compilation due to optimization step error.", file=sys.stderr)
				return

		if len(generated_artifacts) > 0:
				targetQrcFile = tempQrcFile

		# 3. Prepare and execute the rcc command
		cmd = [rccPath, '-binary', '-compress-algo', 'zlib', '-compress', '9', '-threshold', '20']
		cmd.extend(['-o', rccFile, targetQrcFile])

		try:
				result = subprocess.run(cmd, capture_output=True, text=True, check=True)
				if result.stdout:
						print("    rcc output:", result.stdout)
				if result.stderr:
						print("    rcc stderr:", result.stderr)
				print(f"    Successfully generated binary payload: {rccFile}")
		except subprocess.CalledProcessError as e:
				print("    rcc error:", e.stderr, file=sys.stderr)
		except FileNotFoundError:
				print("    rcc not found, perhaps generate .rcc manually from .qrc then pass it with --rcc <filename>")
		finally:
				# 4. Safely purge temporary .tmp text files and .qmlc byte binaries
				if len(generated_artifacts) > 0:
						if os.path.exists(tempQrcFile):
								os.remove(tempQrcFile)
						for artifact in generated_artifacts:
						    if os.path.exists(artifact):
						        os.remove(artifact)

def b64_encode_rcc(name):
		rccFile = "" + name + ".rcc"
		base64Str = ""
		try:
				with open(rccFile, 'rb') as file:
						data = file.read()
						base64data = base64.b64encode(data)
						base64Str = base64data.decode('utf-8')
		except FileNotFoundError as e:
				print("    cannot open " + rccFile + " for reading!", e.stderr, file=sys.stderr)
		return base64Str

def write_compiled_json(output_path, name, version, minRequiredVersion, maxRequiredVersion, translations, integrations, resource):

		dataDict = {
				"name": name,
				"version": version,
				"minRequiredVersion": minRequiredVersion,
				"maxRequiredVersion": maxRequiredVersion,
				"translations": translations,
				"integrations": integrations,
				"resource": resource
		}

		with open(output_path + name+'.json', 'w', encoding='utf-8') as file:
				json.dump(dataDict, file, indent=4)
				file.write('\n')

def strip_empty_sources(tsFiles):
		"""
		Remove <message> entries with empty/whitespace <source> from .ts files.
		"""
		return
		for filename in tsFiles:
				try:
						tree = ET.parse(filename)
						root = tree.getroot()
						changed = False
						for context in list(root.findall('context')):
								for message in list(context.findall('message')):
										source = message.find('source')
										if source is None or (source.text is None) or (source.text.strip() == ''):
												context.remove(message)
												changed = True
								# remove empty contexts
								if len(context.findall('message')) == 0:
										root.remove(context)
										changed = True
						if changed:
								tree.write(filename, encoding='utf-8', xml_declaration=True)
								print("    stripped empty translations from", filename)
				except Exception as e:
						print("    failed to process", filename, e, file=sys.stderr)

def fix_qrc_resources(name):
	file_path=f"./output/{name}.qrc"

	# 1. Read the contents of the file
	with open(file_path, "r", encoding="utf-8") as file:
			file_contents = file.read()

	# 2. Replace the target text
	updated_contents = file_contents.replace("<file>", "<file>../")

	# 3. Write the updated text back to the file
	with open(file_path, "w", encoding="utf-8") as file:
			file.write(updated_contents)


if __name__ == '__main__':
		parser = argparse.ArgumentParser(
				prog='gui-v2-plugin-compiler',
				description='Compiles plugins for gui-v2 into json files')

		parser.add_argument('--rcc', nargs='?', default='') # debugging only...
		parser.add_argument('-n', '--name', default=os.path.basename(os.getcwd()), help='The name of your plugin')
		parser.add_argument('-v', '--version', default='1.0', help='The version of your plugin')
		parser.add_argument('-z', '--min-required-version', default='', help='The minimum gui-v2 version required for the plugin')
		parser.add_argument('-x', '--max-required-version', default='', help='The maximum gui-v2 version compatible with this plugin')
		parser.add_argument('-s', '--settings', default='', help='The main settings page .qml associated with your plugin')
		parser.add_argument('-d', '--devicelist', required=False, nargs='+', action='append', help='Triplet of product id, settings page .qml, and title text (or translation id)')
		parser.add_argument('-g', '--navigation', default='')
		parser.add_argument('-q', '--quickaccess', default='')
		parser.add_argument('-c', '--card', default='')
		parser.add_argument('-f', '--filter-empty-sources', action='store_true', help='Strip empty source entries from .ts files')
		parser.add_argument('-p', '--pre-compile', action=argparse.BooleanOptionalAction)
		parser.add_argument('-m', '--minify', action=argparse.BooleanOptionalAction)

		args = parser.parse_args()
		# print(args.name,file=sys.stderr)
		# print(os.path.basename(os.getcwd()),file=sys.stderr)

		if args.name != os.path.basename(os.getcwd()):
				print("\n\nERROR: plugin name does not match working directory name!", file=sys.stderr)
				sys.exit(1)

		imageFiles = collect_filenames(['.',"./images"], '.svg')
		imageFiles += collect_filenames(['.',"./images"], '.png')
		imageFiles += collect_filenames(['.',"./images"], '.jpg')
		qmlFiles = collect_filenames(['.',"./components"], '.qml')
		qmlFiles += collect_filenames(['.',"./components"], '.js')
		tsFiles = collect_filenames('./translations', '.ts')


		print("--- running lupdate")
		run_lupdate(qmlFiles, tsFiles, args.name)

		if args.filter_empty_sources and tsFiles:
				strip_empty_sources(tsFiles)

		print("--- running lrelease")
		run_lrelease(tsFiles, args.name)
		qmFiles = collect_filenames('.', '.qm')

		print("--- writing .qrc")
		write_qrc(qmlFiles, qmFiles, imageFiles, args.name)

		print("--- running rcc")
		if len(args.rcc) == 0:
				run_rcc(args.name, args.pre_compile , args.minify)

		print("--- base64 encoding rcc data")
		resource = b64_encode_rcc(args.name)

		print("--- building translations array")
		translations = []
		for qmFile in qmFiles:
				translations.append("qrc:/" + args.name + "/" + os.path.basename(qmFile))

		print("--- building integrations dictionary")
		integrations = []
		if len(args.settings) > 0:
				if not args.settings.endswith('.qml'):
						print("\n\nERROR: Invalid settings page specified, must be a .qml file",file=sys.stderr)
						sys.exit(1)
				if not os.path.exists(args.settings):
						print(f"\n\nERROR: Settings page \"{args.settings}\" not found in current directory ({os.path.dirname(os.path.abspath(args.settings))})", file=sys.stderr)
						sys.exit(1)
				settingsIntegration = {
						"type": 1,
						"url": "qrc:/" + args.name + "/" + args.settings
				}
				integrations.append(settingsIntegration)
		if args.devicelist:
				if len(args.devicelist) > 0:
						for integration in args.devicelist:
								if len(integration) != 3:
										print("\n\nERROR: Invalid devicelist triplet!")
										sys.exit(1)
								if not integration[0].startswith(('0x', '0X')):
										print("\n\nERROR: Invalid product id specified in devicelist triplet, must be a hex string starting with 0x", file=sys.stderr)
										sys.exit(1)
								if not integration[1].endswith('.qml'):
										print("\n\nERROR: Invalid settings page specified in devicelist triplet, must be a .qml file", file=sys.stderr)
										sys.exit(1)
								if not os.path.exists(integration[1]):
										print(f"\n\nERROR: Settings page \"{integration[1]}\" not found in current directory ({os.path.dirname(os.path.abspath(integration[1]))})", file=sys.stderr)
										sys.exit(1)
								devicelistIntegration = {
										"type": 2,
										"productId": integration[0],
										"url": "qrc:/" + args.name + "/" + integration[1],
										"title": integration[2]
								}
								integrations.append(devicelistIntegration)
		if len(args.navigation) > 0:
				print("TODO: navigation...")
		if len(args.quickaccess) > 0:
				print("TODO: quick access...")
		if len(args.card) > 0:
				print("TODO: card...")

		print("--- writing compiled json")

		os.makedirs("./output", exist_ok=True)

		write_compiled_json("./output/", args.name, args.version, args.min_required_version, args.max_required_version, translations, integrations, resource)

		if os.path.exists(f"./{args.name}.rcc"):
			os.remove(f"./{args.name}.rcc")

		os.replace(f"./{args.name}.qrc", f"./output/{args.name}.qrc")

		fix_qrc_resources(args.name)
		for qmFile in qmFiles:
			os.remove(qmFile)

		print("--- done!")
		sys.exit(0)
