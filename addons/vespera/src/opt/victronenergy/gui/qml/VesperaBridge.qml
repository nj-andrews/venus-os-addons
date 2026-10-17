import QtQuick 2
import com.victron.velib 1.0

QtObject {
	id: root

	property bool running: false
	property bool stopping: false
	property bool traceEnabled: false
	property int _cancelRequestSeq: 0

	property int _lastStdoutSeq: 0
	property int _lastFinishedSeq: 0
	readonly property string serviceUid: "dbus/com.victronenergy.vespera"

	// When stop() is called, snapshot the seq values at that moment.
	// Any output events with seq > these values are in-flight MQTT
	// messages that were already published before the service saw our cancel;
	// we discard them immediately rather than waiting for the round trip.
	property bool _isCancelling: false
	property int _cancelStdoutSeq: 0

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

	function _snapshotSeqState() {
		_lastStdoutSeq = _toInt(stdoutSeqItem.value)
		_lastFinishedSeq = _toInt(finishedSeqItem.value)
	}

	function waitForFinished(msecs) {
		var _unused = msecs
		if (_unused < 0) return !running
		return !running
	}

	function start(command, action) {

		if (stopping || running) {
			_trace("start() ignored while busy", false)
			return
		}

		if (!command || !action) {
			_trace("start(): invalid args", true)
			error("Invalid args: expected '<command> <action> [args...]'")
			return
		}

		_snapshotSeqState()

		var inputArgs = Array.prototype.slice.call(arguments)
		while (inputArgs.length > 2) {
			var lastArg = inputArgs[inputArgs.length - 1]
			if (lastArg !== null && lastArg !== undefined)
				break
			inputArgs.pop()
		}

		var argsJson = JSON.stringify(inputArgs)
		argsJsonItem.setValue(argsJson)
		resultJsonItem.setValue("") // clear any result

		var startValue = _toInt(startItem.value)
		startItem.setValue(startValue + 1)
		_trace("start(): args=" + argsJson, false)
	}

	function stop() {
		if (stopping || !running) return

		// Snapshot seq values now so we can discard in-flight messages that
		// were already published to MQTT before the service sees the cancel.
		_isCancelling = true
		_cancelStdoutSeq = _toInt(stdoutSeqItem.value)

		_cancelRequestSeq = _cancelRequestSeq + 1
		cancelItem.setValue(_cancelRequestSeq)
		_trace("stop(): cancel requested seqStdout=" + _cancelStdoutSeq, false)
		root.output(qsTrId("vespera_cancelling"))
	}

	function cleanup() {
		stop()
	}

	function _isOperationActive() {
		return root.running || root.stopping
	}

	function _acceptEventSeq(seq, seqPropertyName) {
		if (seq === root[seqPropertyName])
			return false

		root[seqPropertyName] = seq
		return true
	}

	property VeQuickItem stdoutSeqItem: VeQuickItem {
		uid: root.serviceUid + "/Event/StdoutSeq"
		onValueChanged: {
			var seq = root._toInt(root.stdoutSeqItem.value)
			if (!root._acceptEventSeq(seq, "_lastStdoutSeq")) return
			if (root._isCancelling && seq > root._cancelStdoutSeq) return

			var line = root._toString(root.stdoutLineItem.value)
			if (line.length > 0) root.output(line)
		}
	}

	property VeQuickItem finishedSeqItem: VeQuickItem {
		uid: root.serviceUid + "/Event/FinishedSeq"
		onValueChanged: {
			var seq = root._toInt(root.finishedSeqItem.value)
			if (!root._acceptEventSeq(seq, "_lastFinishedSeq")) return

			var exitCode = root._toInt(root.exitCodeItem.value)
			var exitStatus = root._toInt(root.exitStatusItem.value)
			if (root._isCancelling) root.output(qsTrId("vespera_cancelled"))
			var cancelled = root._isCancelling
			root._isCancelling = false

			if (exitCode !== 0) {
				var msg = root._toString(root.resultErrorItem.value)
				if (msg.length > 0) root.error(msg)
			}

			var result = {
				exitCode: exitCode,
				exitStatus: exitStatus,
				cancelled: cancelled,
				success: exitCode == 0 && exitStatus == 0,
				json: root.resultJsonItem.value
			}

			root.finished(result)
		}
	}

	property VeQuickItem statusItem: VeQuickItem {
		uid: root.serviceUid + "/State/Status"
		onValueChanged: {
			var value = root._toInt(root.statusItem.value)
			root.running = value !== 0
			root.stopping = (value & 0x2) == 0x2
		}
	}

	property VeQuickItem argsJsonItem: VeQuickItem { uid: root.serviceUid + "/Request/ArgsJson"}
	property VeQuickItem startItem: VeQuickItem {uid: root.serviceUid + "/Request/Start"}
	property VeQuickItem cancelItem: VeQuickItem {uid: root.serviceUid + "/Request/Cancel"}
	property VeQuickItem stdoutLineItem: VeQuickItem { uid: root.serviceUid + "/Event/StdoutLine"}
	property VeQuickItem exitCodeItem: VeQuickItem { uid: root.serviceUid + "/Result/ExitCode"}
	property VeQuickItem exitStatusItem: VeQuickItem { uid: root.serviceUid + "/Result/ExitStatus"}
	property VeQuickItem resultErrorItem: VeQuickItem { uid: root.serviceUid + "/Result/Error"}
	property VeQuickItem resultJsonItem: VeQuickItem { uid: root.serviceUid + "/Result/Json"}

	Component.onCompleted: {
		var status = _toInt(statusItem.value)
		running = status !== 0
		stopping = (status & 0x2) == 0x2
		_cancelRequestSeq = _toInt(cancelItem.value)
		_snapshotSeqState()
	}
}
