import QtQuick 2
import Victron.VenusOS
import "qrc:/Vespera/components" as Vespera

Page {
	id: root

	required property Vespera.VesperaManager vesperaManager
	property string devicesUid: Global.systemSettings.serviceUid + "/Settings/Devices"

	Vespera.DbusChildModel {
		id: devicesModel
		uid: root.devicesUid
		filterRegExp: "\/sid_[^/]+$"
		childId: "ProductName"
	}

 	GradientListView {
		id: listview
		header: PrimaryListLabel {
			horizontalAlignment: Text.AlignHCenter
			preferredVisible: listview.count === 0
			//% "No Usb devices saved"
			text: qsTrId("vespera_no_devices_saved")
		}

		model: devicesModel

		delegate: ListNavigation {
			id: device
			required property var model
			showAccessLevel: VenusOS.User_AccessType_User
			writeAccessLevel: VenusOS.User_AccessType_Installer

			VeQuickItem {
				id: customNameItem
				uid: model.buddy.uid + "/CustomName"
			}

			text: customNameItem.valid && customNameItem.value
					? customNameItem.value
					: model.value
						? model.value
						: CommonWords.device_info_title
			property bool deviceAdded: false

			function onDeviceAddedCallback(added) {
				if (added !== undefined)
					deviceAdded = added
				return deviceAdded
			}

			onClicked: {
				if (!Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)) {
					Global.showToastNotification(VenusOS.Notification_Info, qsTrId("listItem_no_access"))
					return
				}
				Global.pageManager.pushPage("qrc:/Vespera/PageSettingsSavedDevice.qml",
					{title: text,
					vesperaManager: root.vesperaManager,
					name: model.value,
					serviceUid: model.buddy.uid
					})
			}
		}
	}

}