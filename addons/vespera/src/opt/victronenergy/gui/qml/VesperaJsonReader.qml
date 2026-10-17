// JsonReader.qml
// Self-contained chunk-based JSON reader for vespera.
// Reads named datasets (e.g. "packages", "feeds") from the
// com.victronenergy.vespera service via the /Chunk/ D-Bus paths.

import QtQuick 2
import com.victron.velib 1.0

QtObject {
	id: root

	// Emitted when a dataset has been fully read and parsed.
	signal finished(var result)
	signal error(string error)
	readonly property bool running: _name != ""

	// -- private read-session state --

	property string  _sessionId:     ""
	property string  _sessionBase:   ""
	property string  _name:          ""
	property string  _buffer:        ""
	property string  _sourceVersion: ""
	property int     _nextOffset:    0
	property int     _pendingSeq:    0
	property string vesperaServiceUid: "dbus/com.victronenergy.vespera/Chunk"

	// -- control + request paths (writable) --

	property VeQuickItem _createSession: VeQuickItem { uid: root.vesperaServiceUid + "/Control/CreateSessionId"}
	property VeQuickItem _closeSession: VeQuickItem { uid: root.vesperaServiceUid + "/Control/CloseSessionId"}
	property VeQuickItem _requestJson: VeQuickItem { uid: root.vesperaServiceUid + "/RequestJson"}

	// -- result paths (readable) --
	property VeQuickItem _resSeq: VeQuickItem {
		uid: root._sessionBase.length > 0 ? root._sessionBase + "/Result/Seq" : ""
		onValueChanged: root._onResultSeq(value)
	}
	property VeQuickItem _resData: VeQuickItem {
		uid: root._sessionBase.length > 0 ? root._sessionBase + "/Result/Data" : ""
	}
	property VeQuickItem _resEndOfData: VeQuickItem {
		uid: root._sessionBase.length > 0 ? root._sessionBase + "/Result/EndOfData" : ""
	}
	property VeQuickItem _resSourceVersion: VeQuickItem {
		uid: root._sessionBase.length > 0 ? root._sessionBase + "/Result/SourceVersion" : ""
	}
	property VeQuickItem _resError: VeQuickItem {
		uid: root._sessionBase.length > 0 ? root._sessionBase + "/Result/Error" : ""
	}

	property Timer _timeoutTimer: Timer {
		interval: 5000
		repeat: false
		onTriggered: {
			if (!root.running) return
			root._fail("Chunk request timed out for: " + root._name)
		}
	}

	// -- public API --

	function readAll(name) {
		if (running) {
			var busyError = "JsonReader is busy"
			error(busyError)
			return
		}
		_reset()
		_sessionId     = _newSessionId()
		_sessionBase   = root.vesperaServiceUid + "/Sessions/" + _sessionId
		_createSession.setValue(_sessionId)
		_name          = name
		_requestNextChunk()
	}

	// -- private --

	function _requestNextChunk() {
		if (!running) return
		_pendingSeq += 1

		var requestPayload = {
			sessionId: _sessionId,
			name: _name,
			offset: _nextOffset,
			maxSize: 32768,
			seq: _pendingSeq,
		}
		_timeoutTimer.restart()
		_requestJson.setValue(JSON.stringify(requestPayload))
	}

	function _onResultSeq(seq) {
		if (!running) return
		if (seq === undefined || seq === null) return
		if (parseInt(seq) !== _pendingSeq) return

		if (_timeoutTimer)_timeoutTimer.stop()

		var errText = _resError.value || ""
		if (errText.length > 0) {
			_fail("GetChunkData error (" + _name + "): " + errText)
			return
		}

		var chunkText = _resData.value || ""
		if (chunkText.length > 0) {
			_buffer += chunkText
			_nextOffset += chunkText.length
		}

		var version = _resSourceVersion.value || ""
		if (_sourceVersion.length === 0) {
			_sourceVersion = version
		} else if (version.length > 0 && version !== _sourceVersion) {
			_fail("Source changed during read (version mismatch for: " + _name + ")")
			return
		}

		var endOfData = parseInt(_resEndOfData.value || 0)
		if (endOfData) {
			var result={success:true, json:_buffer}
			_reset()
			finished(result)
		} else {
			_requestNextChunk()
		}
	}

	function _fail(reason) {
		_reset()
		error(reason)
	}

	function _reset() {
		var sessionId = _sessionId
		if (_timeoutTimer) root._timeoutTimer.stop()
		_buffer        = ""
		_sourceVersion = ""
		_name          = ""
		_nextOffset    = 0
		_pendingSeq    = 0
		_sessionId     = ""
		_sessionBase   = ""

		if (sessionId.length > 0)
			_closeSession.setValue(sessionId)
	}

	function _newSessionId() {
		var randomPart = Math.floor(Math.random() * 1000000000).toString(16)
		return "s" + Date.now().toString(16) + randomPart
	}
}