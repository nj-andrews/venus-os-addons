import QtQuick 2

Timer {
	id: root
	interval: 400
	running: false
	repeat: true

	property int _dotCount: 0
	property string text

	function start(text) { root.text = text + "   "; _dotCount = 0; running = true; }
	function stop() { root.running = false, root.text = "" }

	onTriggered: {
		_dotCount = _dotCount % 3 + 1
		text = text.slice(0, -3) + Array(_dotCount+1).join(".") + Array(3 - _dotCount+1).join(" ")
	}
}