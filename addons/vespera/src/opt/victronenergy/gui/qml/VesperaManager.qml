// HARD LINKED
import QtQuick 2

QtObject {
	id: root

	property alias traceEnabled: bridge.traceEnabled
	readonly property bool running: _operationName != "" || _finalizing_install
	readonly property string operationName: _operationName
	property string _operationName: ""
	property bool noAction: noActionSetting.value == 1
	property bool showCompact: showCompactSetting.value == 1
	property var outputLog: null
	property string _lastErrorLine: ""
	property var _completionCallback: undefined
	property var _connected: _connectedItem.value == 1
	readonly property string serviceUid: _connectedItem.vesperaServiceUid
	property bool _finalizing_install: false

	signal log(string line)

	function showToastNotification(level, message, duration) {
		//OVERRIDE
		console.log("Warning: showToastNotification not overriden" )
	}

	function tryPop(toPage) {
		//var _unused = toPage
		if (running && !_finalizing_install) {

			//% "Please wait for the operation to finish"
			root.showToastNotification(0, qsTrId("vespera_wait_for_opkg_operation_to_finish"), 2000)

			return false
		}
		return true
	}

	property VeperaQuickItemAdapter showCompactSetting: VeperaQuickItemAdapter {
		uid: systemSettingsServiceUid + "/Settings/Vespera/ShowCompact"
	}

	property VeperaQuickItemAdapter noActionSetting: VeperaQuickItemAdapter {
		uid: systemSettingsServiceUid + "/Settings/Vespera/NoAction"
	}

	property VeperaBridge bridge: VeperaBridge {
		id: bridge
		traceEnabled: true
	}

	property JsonReader dataReader: JsonReader {
		id: dataReader
	}

	property VeperaQuickItemAdapter _connectedItem: VeperaQuickItemAdapter {
		uid: vesperaServiceUid + "/Connected"
	}

	function cleanup() {
		bridge.cleanup()
	}

	function cancel() {
		if (bridge.running)
			bridge.stop()
	}

	function snapshotObject(source) {
		return source ? JSON.parse(JSON.stringify(source)) : null
	}

	function _writeLog(line) {
		if (line==":::VESPERA-DISABLE:::") {
			_finalizing_install = true
			const Notification_Info=2
			//% "Finiazing install. The UI will restart shortly"
			line = qsTrId("vespera_finalize_install")
			showToastNotification(Notification_Info, line, 5000)
		}

		if (outputLog)
			outputLog.log(line)

		if (traceEnabled)
			console.log(line)

		log(line) // signal
	}

	function _notifyCompletion(result) {

		//var stack = (new Error()).stack
		//root._writeLog("_notifyCompletion:" + stack)

		var callback = root._completionCallback
		var lastError = root._lastErrorLine

		result.operationName = root._operationName
		root._operationName = ""
		root._completionCallback = undefined

		if (!result.success && !result.cancelled) {
			// var warnText="exitCode=" + result.exitCode + ",exitStatus=" + result.exitStatus
			var warnText = _lastErrorLine?.length
				? _lastErrorLine
				: result.error?.length
					? result.error
					: qsTr("Operation failed")
			root.showToastNotification(0, warnText, 3000)
		}

		callback?.(result)

	}

	function addFeed(feedName, url, completionCallback) {
		executeCommand(null,"feed", "add", [feedName, url], completionCallback)
	}

	function removeFeed(feedName, completionCallback) {
		executeCommand(null,"feed", "remove", [feedName], completionCallback)
	}
	function updateFeed(feedName, url, origFeedName, completionCallback) {
		executeCommand(null,"feed", "edit", [feedName, url, origFeedName], completionCallback)
	}

	function loadPackages(update, completionCallback) {
		if (update)
			executeCommand("package load","packages", "update", [], completionCallback)
		else if (initCommand("load packages", completionCallback)) {
			dataReader.readAll("packages")
		}
	}
	function loadFeeds(update, completionCallback) {
		if (update)
			executeCommand("feed load","packages", "update", [], completionCallback)
		else if (initCommand("load feeds", completionCallback)) {
			dataReader.readAll("feeds")
		}
	}

	function installPackage(packageName, completionCallback) {
		var args = _makePackageArgs(packageName)
		executeCommand(null,"package", "install", args, completionCallback)
	}

	function upgradePackage(packageName, completionCallback) {
		var args = _makePackageArgs(packageName)
		executeCommand(null,"package", "upgrade", args, completionCallback)
	}

	function removePackage(packageName, completionCallback) {
		const args = _makePackageArgs(packageName)
		executeCommand(null,"package", "remove", args, completionCallback)
	}

	function _makePackageArgs(packageName) {
		return root.noAction ? [packageName, "--noaction"] : [packageName]
	}

	function setPackageEnabledState(packageName, state, completionCallback) {
		const args = _makePackageArgs(packageName)
		const command = state ? "enabled" : "disabled"
		executeCommand(null,"package", command, args, completionCallback)
	}

	function usbScan(completionCallback) {
		executeCommand(null, "device", "scan", [], completionCallback)
	}
	function bindDeviceToService(port, serviceName, completionCallback) {
		//var reconnectArg = reconnect ? "true" : ""
		executeCommand(null,"device", "bind", [port, serviceName], completionCallback)
	}

	function removeDevice(sid, completionCallback) {
		executeCommand(null,"device", "remove", [sid], completionCallback)
	}

	function initCommand(operationName, completionCallback) {

		var error
		if (!_connected) error = "Vepera Service not running"
		if (!error && bridge.running) error = "Command processor already running"
		if (error) {
			var result = {success: false, error: error}
			root.showToastNotification(0,result.error, 3000)
			completionCallback?.(result)
			return false
		}
		root._operationName = operationName
 		root._completionCallback = (completionCallback && completionCallback.call) ? completionCallback : undefined

		return true
	}

	function executeCommand(operationName, familyName, commandName, args, completionCallback) {
		var opName = operationName || familyName + " " + commandName
		if (!initCommand(opName, completionCallback))
			return

		bridge.start(familyName, commandName, ...(args || []))
	}

	function logError(error) {
		root._lastErrorLine = error
		root._writeLog(error)
	}

	property Connections bridgeConnections: Connections {
		target: bridge

		function onOutput(line) {
			root._writeLog(line)
		}

		function onError(error) {
			root.logError(error)
		}

		function onFinished(result) {
			console.log("onFinished in:" + root.operationName + ", exitCode:" + result.exitCode + ", exitStatus:" + result.exitStatus)

			var notifyCalled = false

			try {
				if (result.success) {
					if (root.operationName.startsWith("package ")) {
						dataReader.readAll("packages")
						return
					} else if (root.operationName.startsWith("feed ")) {
						console.log("dataReader.readAll:feeds")
						dataReader.readAll("feeds")
						return
					}
				}

				var data
				if (result.json?.length) {
					result.data = JSON.parse(result.json)
					delete result.json;
				}

				notifyCalled = true
				root._notifyCompletion(result)

			} catch (e) {
				root.logError("ERROR:onFinished: " + e)
				result.error = e
				result.success = false
				if (!notifyCalled)
					root._notifyCompletion(result)
			}
		}

	}

	property Connections readerConnections: Connections {
		target: dataReader

		function onJsonReady(jsonData, jsonText, name) {
			root._notifyCompletion({exitCode:0, exitStatus:0, success: true, data:jsonData})
		}

		function onJsonError(error, name) {
			root.logError(error)
			root._notifyCompletion({exitCode:1, exitStatus:0, success: false, error:error})
		}
	}
}