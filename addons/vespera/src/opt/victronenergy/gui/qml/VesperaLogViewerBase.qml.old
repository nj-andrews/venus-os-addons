// HARD LINKED
import QtQuick 2

Rectangle {
	id: root

	property bool isWorking: false
	property int dotCount: 1
	property string baseWorking: ""
	property bool autoFollow: true
	property int maxLines: 1000
	property int batchIntervalMs: 33

	property var _pendingLines: []
	property int fontSize
	property color defaultLineColor
	property color successLineColor
	property color warningLineColor
	property color errorLineColor
	property alias backgroundColor : root.color

	radius: 4

	ListModel {
		id: logModel
	}

	ListView {
		id: logView
		anchors.fill: parent
		anchors.margins: 6
		clip: true
		model: logModel
		spacing: 0

		onMovementStarted: {
			if (!logView.atYEnd) {
				root.autoFollow = false
			}
		}

		delegate: Text {
			id: lineText
			required property string line
			required property string severity
			text: line
			width: ListView.view ? ListView.view.width : 0
			wrapMode: Text.WrapAnywhere
			horizontalAlignment: Text.AlignLeft
			verticalAlignment: Text.AlignTop
			color: severity === "error"
				? root.errorLineColor
				: severity === "warning"
					? root.warningLineColor
					: severity === "success"
						? root.successLineColor
						: root.defaultLineColor
			font.pixelSize: root.fontSize
		}
	}

	Timer {
		id: appendTimer
		interval: root.batchIntervalMs
		repeat: false
		onTriggered: {
			root._flushPending()
		}
	}

	Timer {
		id: progressTimer
		interval: 400
		running: root.isWorking
		repeat: true
		onTriggered: {
			if (logModel.count > 0) {
				root.dotCount = root.dotCount % 3 + 1
				logModel.setProperty(logModel.count - 1, "line", root.baseWorking + Array(root.dotCount + 1).join("."))
				root._followBottomIfNeeded()
			}
		}
	}

	function _flushPending() {
		if (!root._pendingLines || root._pendingLines.length === 0) {
			return
		}

		var lines = root._pendingLines
		root._pendingLines = []

		for (var i = 0; i < lines.length; ++i) {
			logModel.append(lines[i])
		}

		var overflow = logModel.count - root.maxLines
		if (overflow > 0) {
			logModel.remove(0, overflow)
		}

		root._followBottomIfNeeded()
	}

	function _followBottomIfNeeded() {
		if (root.autoFollow || logView.atYEnd) {
			logView.positionViewAtEnd()
			root.autoFollow = true
		}
	}

	function _lineSeverity(line) {
		var text = String(line)
		if (/^\s*(?:error\b|✗)/i.test(text)) {
			return "error"
		}
		if (/^\s*(?:warning\b|⚠)/i.test(text)) {
			return "warning"
		}
		if (/^\s*✓/i.test(text)) {
				return "success";
		}
		return "info"
	}

	function _queueLine(line) {
		var text = String(line)
		root._pendingLines.push({
			line: text,
			severity: root._lineSeverity(text)
		})
		if (!appendTimer.running) {
			appendTimer.start()
		}
	}

	function startIsWorking(line, clear) {
		if (clear) {
			root.clear()
		}
		log(line)
		baseWorking = String(line)
		isWorking = true
		dotCount = 1
	}

	function stopIsWorking(clear) {
		if (clear) {

			root._pendingLines = []
			appendTimer.stop()
			logModel.clear()
			root.autoFollow = true
			return
		}

		if (!isWorking) {
			return
		}

		isWorking = false
		progressTimer.stop()
		_flushPending()
		if (logModel.count > 0) {
			logModel.setProperty(logModel.count - 1, "line", baseWorking)
			root._followBottomIfNeeded()
		}
		dotCount = 1
	}

	function clear() {
		stopIsWorking(true)
	}

	function log(line) {
		stopIsWorking(false)
		if (line.endsWith("...")) {
			startIsWorking(line.slice(0, -3))
			return
		}
		_queueLine(line)
	}


}
