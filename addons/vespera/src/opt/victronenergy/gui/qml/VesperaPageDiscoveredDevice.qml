import QtQuick 2
import com.victron.velib 1.0

MbPage {
	id: root
	title: qsTrId("vespera_add_usb_serial_device")

	required property VesperaManager vesperaManager
	required property string serviceUid
	required property string port
	required property var deviceAddedCallback

	property string selectedDeviceServiceName: ""
	property var addingDeviceText: progressText.running ? progressText.text : ""
	property bool deviceAdded: deviceAddedCallback !== undefined ? deviceAddedCallback() : false
	property var jsonUsbProps: usbPropsItem.value != undefined ? usbPropsToFormatedJson(usbPropsItem.value) : {}

	function usbPropsToFormatedJson(str) {
		return str.split(",").map(function(p) {
			var a = p.split("="), n = a[0].replace(/^ID_|_ID$/g, "").replace(/[-_]+/g, " ")
			return {name: n.charAt(0).toUpperCase() + n.slice(1).toLowerCase(), value: a.slice(1).join("=")}
		})
	}

	pageToolbarHandler: addDeviceToolbarHandler

	VeQuickItem {
		id: usbPropsItem
    uid: serviceUid + "/UsbProps"
  }

	model: VisualModels {
		VisibleItemModel {
			MbItemOptions {
				id: selectServiceType

				description: qsTrId("vespera_serial_device_service")
				unknownOptionText: qsTrId("vespera_press_to_select_service")
				value: root.selectedDeviceServiceName
				onOptionSelected: function (newValue) { root.onSerialDeviceServiceSelected(newValue) }
				//Fix for spacebar not working after DelegateModel use!
				Keys.onSpacePressed: { edit() }
			}
			MbItemRow { description: qsTrId("vespera_port")
				values: [MbTextBlock { item.text: root.port} ]}
		}

		DelegateModel {
			model: root.jsonUsbProps
			delegate: MbItemRow { description: modelData.name
				values: [MbTextBlock { item.text: modelData.value} ]}
		}

	}

	VesperaProgressText { id: progressText}
	Component  { id: mbOptionFactory; MbOption {}}

	VeQItemSortTableModel {
		id: enabledDeviceServices
		dynamicSortFilter: true
		filterRole: VeQItemTableModel.UniqueIdRole
		filterRegExp: "\\/Packages\\/[^/]+\\/(DeviceServices\\/[0-9]+\\/(DisplayName|ServiceName)|Enabled)$"

		model: VeQItemTableModel {
			uids: ["dbus/com.victronenergy.settings/Settings/Vespera/Packages"]
			flags: VeQItemTableModel.AddAllChildren |
					VeQItemTableModel.AddNonLeaves |
					VeQItemTableModel.DontAddItem
		}
		filterFlags: VeQItemSortTableModel.FilterOffline

		Component.onCompleted: enabledDeviceServices.updateAvailableServices()
		onRowCountChanged: enabledDeviceServices.updateAvailableServices()

		function updateAvailableServices() {
			var byServiceMap = {}

			for (var row = 0; row < rowCount; row++) {
				var idx = index(row, VeQItemTableModel.ValueColumn)
				var uid = data(idx, VeQItemTableModel.UniqueIdRole)
				var value = data(idx, VeQItemTableModel.ValueRole)
				if (/\/Packages\/[^/]+\/Enabled$/.test(uid)) {
					var packageBase = uid.replace(/\/Enabled$/, "")
					if (!byServiceMap[packageBase])
						byServiceMap[packageBase] = { enabled: false }
					byServiceMap[packageBase].enabled = (Number(value) === 1)
					// console.log( "enabled=",byServiceMap[packageBase].enabled)
					continue
				}
				var serviceBase = ""
				if (/\/DeviceServices\/[0-9]+\/(DisplayName|ServiceName)$/.test(uid))
					serviceBase = uid.replace(/\/(DisplayName|ServiceName)$/, "")

				if (serviceBase) {
					if (!byServiceMap[serviceBase])
						byServiceMap[serviceBase] = { packageBase: serviceBase.replace(/\/DeviceServices\/[0-9]+$/, ""),displayName: "", serviceName: "" }

					if (/\/DisplayName$/.test(uid))
						byServiceMap[serviceBase].displayName = value
					else if (/\/ServiceName$/.test(uid))
						byServiceMap[serviceBase].serviceName = value
				}
			}

			var availableServices = Object.keys(byServiceMap)
					.map(function(base) { return byServiceMap[base] })
					.filter(function(s) {
							return s.serviceName &&
										s.packageBase &&
										byServiceMap[s.packageBase] &&
										byServiceMap[s.packageBase].enabled === true
					})

			var options = availableServices.map(function(s) {
					return mbOptionFactory.createObject(root, {
							description: s.displayName || s.serviceName,
							value: s.serviceName
					})
			})
			selectServiceType.possibleValues = options

			if (!root.selectedDeviceServiceName &&  availableServices.length > 0)
				root.selectedDeviceServiceName = availableServices[0].serviceName
		}
	}

	function onSerialDeviceServiceSelected(newValue)	{
		var changed = root.selectedDeviceServiceName != "" && root.selectedDeviceServiceName != newValue
		root.selectedDeviceServiceName = newValue
	}


	function addDevice() {
		// if (!Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)) {
		// 	Global.showToastNotification(VenusOS.Notification_Info, qsTrId("listItem_no_access"))
		// 	return
		// }
		if (progressText.running || !root.selectedDeviceServiceName)
			return

		//% "Adding Device"
		var addingDevice = qsTrId("vespera_adding_device")
		progressText.start(addingDevice)

		// var sid = root.serviceUid.split('/').pop()
		// sid = sid.replace(/^sid_/, "");
		// console.log("BBB:",root.selectedDeviceServiceName)
		root.vesperaManager.bindDeviceToService(
			root.port, root.selectedDeviceServiceName,
			function(result) {
				if (progressText)
					progressText.stop()

				if (result) {
					Global.pageManager.popPage()
					//% "Device Added Successfully\nThe service will start shortly..."
					var successMessage = qsTrId("vespera_added_device_success")
					Global.showToastNotification(VenusOS.Notification_Info, successMessage, 5000)
				}
			}

		)
	}

	ToolbarHandler {
		id: addDeviceToolbarHandler
	  leftText: progressText.running
			? root.addingDeviceText
		 	: !root.deviceAdded && root.selectedDeviceServiceName
				? qsTranslate("PageSettingsModbusDevices", "Add")
				: ""
		function leftAction() { root.addDevice() }
	}
}
