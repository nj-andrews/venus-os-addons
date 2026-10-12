import QtQuick 2
import Victron.VenusOS
import "qrc:/Vespera/components" as Vespera

Page {
	id: root
	//% "Saved USB serial device"
	title: qsTrId("vespera_saved_usb_serial_device")

	required property Vespera.VesperaManager vesperaManager
	required property string name
	required property string serviceUid
	property var removingDeviceText: progressText.running ? progressText.text : ""
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
	Vespera.ProgressText { id: progressText }

	GradientListView {
		header: SettingsColumn {

			width: parent.width
			bottomPadding: spacing

			SettingsListHeader {
				//% "Device Properties"
				text: qsTrId("vespera_device_properties")
			}
			ListText {
				//% "Device name"
				text: qsTrId("vespera_device_name")
				secondaryText: root.name
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
				//% "Remove Device"
				secondaryText: qsTrId("vespera_remove_device")
				showAccessLevel: VenusOS.User_AccessType_User
				writeAccessLevel: VenusOS.User_AccessType_Installer
				enabled: Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)
				onClicked: {
					if (!Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)) {
						Global.showToastNotification(VenusOS.Notification_Info, qsTrId("listItem_no_access"))
						return
					}
					Global.dialogLayer.open(modeConfirmationDialogComponent)
				}
			}
		}
	}

	function removeDevice() {
		if (!Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)) {
			Global.showToastNotification(VenusOS.Notification_Info, qsTrId("listItem_no_access"))
			return
		}
		var sid = root.serviceUid.split('/').pop()
		sid = sid.replace(/^sid_/, "");

		//% "Removing Device"
		progressText.start(qsTrId("vespera_removing_device"))

		root.vesperaManager.removeDevice(
			sid, function(result) {
				if (progressText)
					progressText.stop()
				if (result.success) {
					//% "Device successfully removed"
					var successMessage = qsTrId("vespera_device_successfully_removed")
					Global.showToastNotification(VenusOS.Notification_Info, successMessage, 5000)
				}
			}
		)
		Global.pageManager.popPage()
	}

	Component {
		id: modeConfirmationDialogComponent

		ModalWarningDialog {
			//% "Are you sure?"
			title: qsTrId("vespera_are_you_sure")
			//% "Clicking yes will permanently remove this devices settings"
			description: qsTrId("vespera_remove_device_description")
			dialogDoneOptions: VenusOS.ModalDialog_DoneOptions_OkAndCancel
			onAccepted: root.removeDevice()
		}
	}
}
