pragma ComponentBehavior: Bound

import QtQuick 2
import Victron.VenusOS
import "./components" as Vespera

Page {
	id: root
	//% "Add USB serial device"
	title: qsTrId("vespera_add_usb_serial_device")

	required property Vespera.VesperaManager vesperaManager
	required property string port
	required property string serviceUid

	property var availableServices: []
	property string selectedDeviceServiceName
	property var addingDeviceText: progressText.running ? progressText.text : ""
	property var jsonUsbProps: usbPropsItem.valid ? usbPropsToFormatedJson(usbPropsItem.value) : {}


	function usbPropsToFormatedJson(str) {
		return str.split(",").map(function(p) {
			var a = p.split("="), n = a[0].replace(/^ID_|_ID$/g, "").replace(/[-_]+/g, " ")
			return {name: n.charAt(0).toUpperCase() + n.slice(1).toLowerCase(), value: a.slice(1).join("=")}
		})
	}

	VeQuickItem {
		id: usbPropsItem
		uid: root.serviceUid + "/UsbProps"
	}

	Vespera.ProgressText { id: progressText}

	VeQItemSortTableModel {
		id: enabledDeviceServices
		dynamicSortFilter: true
		filterRole: VeQItemTableModel.UniqueIdRole
		filterRegExp: "\\/Packages\\/[^/]+\\/(DeviceServices\\/[0-9]+\\/(DisplayName|ServiceName)|Enabled)$"

		model: VeQItemTableModel {
			uids: [Global.systemSettings.serviceUid + "/Settings/Vespera/Packages"]
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

			root.availableServices = Object.keys(byServiceMap)
					.map(function(base) { return byServiceMap[base] })
					.filter(function(s) { return s.serviceName &&
							s.packageBase && byServiceMap[s.packageBase] && byServiceMap[s.packageBase].enabled === true})
					.map(function(s) {
					return { display: s.displayName || s.serviceName, value: s.serviceName }
					})

		}
	}

	GradientListView {
		header: SettingsColumn {

			width: parent.width
			bottomPadding: spacing

			SettingsListHeader {
				//% "Device Options"
				text: qsTrId("vespera_device_options")
			}
			ListRadioButtonGroup {
				id: selectServiceType
				optionModel: root.availableServices
				showAccessLevel: VenusOS.User_AccessType_User
				writeAccessLevel: VenusOS.User_AccessType_Installer
				optionHeader: Component {
					//% "No service templates installed"
					ListText { text: qsTrId("vespera_no_service_templates"); preferredVisible: root.availableServices.length == 0 }
				}
				//% "Serial Device Service"
				text: qsTrId("vespera_serial_device_service")
				//% "Press to select service"
				defaultSecondaryText: qsTrId("vespera_press_to_select_service")

				onOptionClicked: function(index) {
					currentIndex = index
					if (index >= 0 && index < root.availableServices.length)
						root.selectedDeviceServiceName = root.availableServices[index].value
				}
			}

			SettingsListHeader {
				//% "Device Properties"
				text: qsTrId("vespera_device_properties")
			}
			ListText {
				//% "Port"
				text: qsTrId("vespera_port")
				secondaryText: root.port
			}
		}

		model: root.jsonUsbProps

		delegate: ListText {
				required property var model
				width: parent.width
				text: model.name
				secondaryText: model.value
		}

		footer: SettingsColumn {
			width: parent.width
			topPadding: spacing
			ListButton {
				secondaryText: progressText.running ? progressText.text : CommonWords.add_device
				enabled: root.selectedDeviceServiceName && root.selectedDeviceServiceName.length > 0 && Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)
				showAccessLevel: VenusOS.User_AccessType_User
				writeAccessLevel: VenusOS.User_AccessType_Installer
				onClicked: root.addDevice()
				implicitWidth: 100
			}
		}
	}

	function addDevice() {
		if (!root.vesperaManager.installerAccess()) return

		if (!root.selectedDeviceServiceName)
			return
		if (progressText.running)
			return

		//% "Adding Device"
		progressText.start(qsTrId("vespera_adding_device"))

		// var sid = root.serviceUid.split('/').pop()
		// sid = sid.replace(/^sid_/, "");
		// console.log("BBB:",root.selectedDeviceServiceName)
		root.vesperaManager.bindDeviceToService(
			root.port, root.selectedDeviceServiceName,
			function(result) {
				if (progressText)
					progressText.stop()

				if (result.success) {
					Global.pageManager.popPage()
					//% "Device Added Successfully\nThe service will start shortly..."
					var successMessage = qsTrId("vespera_added_device_success")
					Global.showToastNotification(VenusOS.Notification_Info, successMessage, 5000)
				}
			}

		)
	}

}
