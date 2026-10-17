#!/usr/bin/env python3
import argparse
import os
import re


STRING_LITERAL_RE = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')


def minify_qml_text(content: str) -> str:
    """
    Safely minifies QML text by stripping comments, trimming padding,
    removing empty lines, and collapsing structural newlines.
    """
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

    collapsed_content = "\n".join(cleaned_lines)

    # 4. Safe structural collapsing
    collapsed_content = re.sub(r'\n\s*\{', ' {', collapsed_content)
    collapsed_content = re.sub(r'\{\s*\n\s*', '{ ', collapsed_content)
    collapsed_content = re.sub(r'\n\s*([?:])\s*', r' \1 ', collapsed_content)
    collapsed_content = re.sub(r'\n\s*\+\s*', ' + ', collapsed_content)
    collapsed_content = re.sub(r'(?<=\S)\n\s*\.\s*', '.', collapsed_content)
    collapsed_content = re.sub(r'\n\s*\)', ')', collapsed_content)
    collapsed_content = re.sub(r'\n\s*\}', '}', collapsed_content)

    # 5. Extra punctuation cleanup without tokenizing the file.
    collapsed_content = re.sub(r'\s*([,;])\s*', r'\1', collapsed_content)
    collapsed_content = re.sub(r'\s*([=+\-*/%<>!&|])\s*', r'\1', collapsed_content)
    collapsed_content = re.sub(r'(?<!\d)\s*\.\s*(?!\d)', '.', collapsed_content)

    # 5b. Additive spacing cleanup that preserves existing line feeds.
    parts = re.split(f'({STRING_LITERAL_RE.pattern})', collapsed_content)
    for index, part in enumerate(parts):
        if not part or STRING_LITERAL_RE.fullmatch(part):
            continue
        part = re.sub(r'[ \t]*(===|!==|==|!=)[ \t]*', r'\1', part)
        part = re.sub(r'[ \t]*([:+\-*=?{}(),])[ \t]*', r'\1', part)
        parts[index] = part
    collapsed_content = ''.join(parts)

    return collapsed_content


def minify_qml_file(input_path: str, output_path: str) -> None:
    with open(input_path, 'r', encoding='utf-8') as src:
        content = src.read()

    output_dir = os.path.dirname(output_path)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as dst:
        dst.write(minify_qml_text(content))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Minify a QML file.')
    parser.add_argument('input', help='Path to the input .qml file')
    parser.add_argument('output', help='Path to the output .qml file')
    args = parser.parse_args()

    minify_qml_file(args.input, args.output)
