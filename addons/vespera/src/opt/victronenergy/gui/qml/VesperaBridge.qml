import QtQuick 2
import com.victron.velib 1.0

// Starts commands through com.victronenergy.vespera (/Request/*) and follows their progress through
// the /Settings/Vespera/Gui/* settings written by scripts/gui-executor:
//   Output   - latest output line
//   ExitCode - -1 while running, then the exit code
QtObject {
	id: root

	property bool running: false
	property bool traceEnabled: false

	readonly property string serviceUid: "dbus/com.victronenergy.vespera"
	readonly property string guiSettingsUid: "dbus/com.victronenergy.settings/Settings/Vespera/Gui"

	// ExitCode only changes once gui-executor has started; if it never does, give up
	readonly property int startTimeoutMs: 10000
	property bool _seenRunning: false

	signal output(string line)
	signal error(string line)
	signal finished(var result)

	function _toInt(value) {
		var n = Number(value)
		if (!isFinite(n)) return 0
		return Math.floor(n)
	}

	function _toString(value) {
		if (value === undefined || value === null) return ""
		return String(value)
	}

	function _trace(line, isError) {
		if (!traceEnabled) return
		if (isError) {
			console.error("[Bridge] " + line)
			return
		}
		console.log("[Bridge] " + line)
	}

	function start(command, action) {
		console.log("VESPERA:start in")
		if (running) {
			_trace("start() ignored while busy", false)
			return
		}

		if (!command || !action) {
			_trace("start(): invalid args", true)
			error("Invalid args: expected '<command> <action> [args...]'")
			return
		}

		var inputArgs = Array.prototype.slice.call(arguments)
		while (inputArgs.length > 2) {
			var lastArg = inputArgs[inputArgs.length - 1]
			if (lastArg !== null && lastArg !== undefined)
				break
			inputArgs.pop()
		}

		var argsJson = JSON.stringify(inputArgs)
		_seenRunning = false
		running = true
		startTimer.restart()

		argsJsonItem.setValue(argsJson)
		startItem.setValue(_toInt(startItem.value) + 1)
		_trace("start(): args=" + argsJson, false)
	}

	function _finish(exitCode) {
		startTimer.stop()
		_seenRunning = false
		running = false
		root.finished({
			exitCode: exitCode,
			exitStatus: 0,
			cancelled: false,
			success: exitCode === 0
		})
	}

	property Timer startTimer: Timer {
		interval: root.startTimeoutMs
		onTriggered: {
			if (!root.running || root._seenRunning) return
			root.error("Command did not start")
			root._finish(-1)
		}
	}

	property VeQuickItem outputItem: VeQuickItem {
		uid: root.guiSettingsUid + "/Output"
		onValueChanged: {
			if (!root.running) return
			var line = root._toString(root.outputItem.value)
			if (line.length > 0) root.output(line)
		}
	}

	property VeQuickItem exitCodeItem: VeQuickItem {
		uid: root.guiSettingsUid + "/ExitCode"
		onValueChanged: {
			if (root.exitCodeItem.value === undefined) return
			var exitCode = root._toInt(root.exitCodeItem.value)

			// -1 also adopts a command that was already running before this GUI loaded
			if (exitCode === -1) {
				root._seenRunning = true
				root.running = true
				startTimer.stop()
				return
			}

			if (root.running && root._seenRunning)
				root._finish(exitCode)
		}
	}

	property VeQuickItem argsJsonItem: VeQuickItem { uid: root.serviceUid + "/Request/ArgsJson"}
	property VeQuickItem startItem: VeQuickItem {uid: root.serviceUid + "/Request/Start"}
}
