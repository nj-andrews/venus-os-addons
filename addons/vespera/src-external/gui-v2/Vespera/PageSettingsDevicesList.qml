import QtQuick 2
import Victron.VenusOS
import "qrc:/Vespera/components" as Vespera

Page {
	id: root
	//% "Custom Devices"
	title: qsTrId("vespera_custom_devices")
	tryPop: vesperaManager.tryPop

	property Vespera.VesperaManager vesperaManager
	property string service: "com.victronenergy.vespera"
	property string settings: "com.victronenergy.settings/Settings/Vespera"

	Component {
		id: vesperaManagerFactory
		Vespera.VesperaManager {}
	}

	Component.onCompleted: {
		if (vesperaManager == null)
			vesperaManager = vesperaManagerFactory.createObject(root)
	}

	function toggleScan() {
		if (!Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)) {
			Global.showToastNotification(VenusOS.Notification_Info, qsTrId("listItem_no_access"))
			return
		}
		if (vesperaManager.running) {
			vesperaManager.cancel()
			return
		}

		progressText.start(CommonWords.scanning.arg("").slice(0, -1))
		vesperaManager.usbScan(function (result) {
			if (progressText)
				progressText.stop()
		})
		showDiscoveredDevicesPage()
	}

	function showDiscoveredDevicesPage() {
		if (!Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)) {
			Global.showToastNotification(VenusOS.Notification_Info, qsTrId("listItem_no_access"))
			return
		}
		Global.pageManager.pushPage("qrc:/Vespera/PageSettingsDiscoveredDevices.qml", {
			vesperaManager: root.vesperaManager,
			progressText: progressText})
	}
	Vespera.ProgressText {id: progressText}

	GradientListView {
		model: VisibleItemModel {

			ListButton {
				// "Scan for devices"
				text: qsTrId("page_settings_modbus_scan_for_devices")
				secondaryText: progressText.running  ? progressText.text : CommonWords.scan_action
				showAccessLevel: VenusOS.User_AccessType_User
				writeAccessLevel: VenusOS.User_AccessType_Installer
				onClicked: {
					if (!Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)) {
						Global.showToastNotification(VenusOS.Notification_Info, qsTrId("listItem_no_access"))
						return
					}
					root.toggleScan()
				}
				preferredVisible: userHasWriteAccess
			}

			ListNavigation {
				// "Saved devices"
				text: qsTrId("page_settings_modbus_saved_devices")
				showAccessLevel: VenusOS.User_AccessType_User
				writeAccessLevel: VenusOS.User_AccessType_Installer
				//secondaryText: subpage.model.count //TODO
				onClicked: {
					if (!Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)) {
						Global.showToastNotification(VenusOS.Notification_Info, qsTrId("listItem_no_access"))
						return
					}
					Global.pageManager.pushPage("qrc:/Vespera/PageSettingsSavedDevices.qml", {"title": text, vesperaManager: root.vesperaManager})
				}
			}

			ListNavigation {
				text: CommonWords.discovered_devices
				showAccessLevel: VenusOS.User_AccessType_User
				writeAccessLevel: VenusOS.User_AccessType_Installer
				//secondaryText: subpage.model.count //TODO
				onClicked: {
					if (!Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)) {
						Global.showToastNotification(VenusOS.Notification_Info, qsTrId("listItem_no_access"))
						return
					}
					root.showDiscoveredDevicesPage()
				}
			}
		}
	}

}