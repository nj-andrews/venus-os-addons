import QtQuick 2
import Victron.VenusOS

QtObject {
	id: root

	signal log(string str)

	property alias traceEnabled: bridge.traceEnabled
	readonly property bool running: _running
	property bool _running
	readonly property string operationName: _operationName
	property string _operationName: ""
	property var _completionCallback: undefined
	property var _connected: _connectedItem.value == 1
	readonly property string serviceUid: BackendConnection.serviceUidFromName("com.victronenergy.vespera", 0)

	function tryPop(toPage) {
		if (!running) return true
		//% "Please wait for the operation to finish"
		showToastNotification(0, qsTrId("vespera_wait_for_operation_to_finish"), 2000)
		return false
	}

	function installerAccess() {
		if (Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer))
			return true
		//% "No access"
		showToastNotification(VenusOS.Notification_Info, qsTrId("listItem_no_access"))
		return false
	}

	function showToastNotification(level, message, duration) {
		Global.showToastNotification(level, message, duration)
	}

	property VesperaBridge bridge: VesperaBridge {
		id: bridge
		traceEnabled: true
		onOutput: function(line) { root._writeLog(line)}
		onError: function(error) { root._writeLog(error)}
		onFinished: function (result) { root._onFinished(result) }
	}

	property VesperaJsonReader dataReader: VesperaJsonReader {
		id: dataReader
		onFinished: function (result) { root._onFinished(result) }
		onError: function(error) { root._writeLog(error) }
	}

	property VeQuickItem _connectedItem: VeQuickItem { uid: root.serviceUid + "/Connected" }

	function cleanup() { bridge.cleanup() }

	function cancel() {
		if (bridge.running) bridge.stop()
	}

	function snapshotObject(source) {
		return source ? JSON.parse(JSON.stringify(source)) : null
	}

	function _onFinished(result) {
		console.log("onFinished in:", root.operationName , "exitCode:", result.exitCode, "exitStatus:", result.exitStatus, "success:", result.success)

		var notifyCalled = false

		try {
			if (typeof result.json === "string" && result.json.length > 0) {
				result.data = JSON.parse(result.json)
				delete result.json;
			}

			notifyCalled = true
			root._notifyCompletion(result)

		} catch (e) {
			var errorText = e && e.stack ? (e.name + ": " + e.message + " @ " + e.stack.split("\n")[0]) : String(e)
			root._writeLog("ERROR:onFinished: " + errorText)
			result.error = errorText
			result.success = false
			if (!notifyCalled)
				root._notifyCompletion(result)
		}
	}

	function _writeLog(line) {
		if (line==":::VESPERA-GUI-INTERRUPT:::") {
			const Notification_Info=2
			//% "Finalizing. The UI will restart shortly"
			line = qsTrId("vespera_finalize_install")
			showToastNotification(Notification_Info, line, 5000)
		}

		if (traceEnabled) console.log(line)

		log(line)
	}

	function _notifyCompletion(result) {

		var callback = root._completionCallback

		result.operationName = root._operationName
		root._operationName = ""
		root._completionCallback = undefined

		if (!result.success && !result.cancelled) {
			//% "Operation failed"
			var warnText = qsTrId("vespera_operation_failed")
			showToastNotification(0, warnText, 3000)
		}

		callback?.(result)
		_running = false
	}

	function addFeed(feedName, url, completionCallback) {
		_executeCommand(null,"feed", "add", [feedName, url], completionCallback)
	}

	function removeFeed(feedName, completionCallback) {
		_executeCommand(null,"feed", "remove", [feedName], completionCallback)
	}
	function updateFeed(feedName, url, origFeedName, completionCallback) {
		_executeCommand(null,"feed", "edit", [feedName, url, origFeedName], completionCallback)
	}

	function loadPackages(update, completionCallback) {
		_load_feeds_packages("packages", update, completionCallback)
	}
	function loadFeeds(update, completionCallback) {
		_load_feeds_packages("feeds", update, completionCallback)
	}

	function _load_feeds_packages(name, update, completionCallback) {
		if (update) {
			_executeCommand(name + " update", "packages", "update", [], function (result) {
				if (result.success)
					if (initCommand(name + " load", completionCallback))
								dataReader.readAll(name)
			})
		} else if (initCommand(name + " load", completionCallback)) {
			dataReader.readAll(name)
		}
	}

	function installPackage(packageName, completionCallback) {
		_executeCommand(null, "package", "install", [packageName], completionCallback)
	}

	function upgradePackage(packageName, completionCallback) {
		_executeCommand(null,"package", "upgrade", [packageName], completionCallback)
	}

	function removePackage(packageName, completionCallback) {
		_executeCommand(null,"package", "remove", [packageName], completionCallback)
	}

	function setPackageEnabledState(packageName, state, completionCallback) {
		const command = state ? "enable" : "disable"
		_executeCommand(null,"package", command, [packageName], completionCallback)
	}

	function usbScan(completionCallback) {
		_executeCommand(null, "device", "scan", [], completionCallback)
	}
	function bindDeviceToService(port, serviceName, completionCallback) {
		_executeCommand(null,"device", "bind", [port, serviceName], completionCallback)
	}

	function removeDevice(sid, completionCallback) {
		_executeCommand(null,"device", "remove", [sid], completionCallback)
	}

	function initCommand(operationName, completionCallback) {

		var error
		if (!_connected) error = "Vepera Service not running"
		if (!error && bridge.running) error = "Command processor already running"
		if (error) {
			var result = {success: false, error: error}
			showToastNotification(0,result.error, 3000)
			completionCallback?.(result)
			return false
		}
		root._operationName = operationName

 		root._completionCallback = (completionCallback && completionCallback.call) ? completionCallback : undefined
		root._running = true
		return true
	}

	function _executeCommand(operationName, familyName, commandName, args, completionCallback) {
		var opName = operationName || familyName + " " + commandName
		if (!initCommand(opName, completionCallback))
			return

		bridge.start(familyName, commandName, ...(args || []))
	}

}