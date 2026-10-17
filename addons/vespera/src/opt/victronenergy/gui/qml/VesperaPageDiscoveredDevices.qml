import QtQuick 2
import com.victron.velib 1.0

MbPage {
	id: root

	required property VesperaManager vesperaManager
	required property MbStyle mbStyle: MbStyle {}

	VesperaDbusChildModel {
		id: devicesModel
		uid: "dbus/com.victronenergy.vespera/Discovered"
		filterRegExp: "\/sid_[^/]+$"
		childId: "Port"
	}
	listview.visible: devicesModel.rowCount > 0

	Text {
		text: qsTrId("vespera_no_devices_discovered")
		font.pixelSize: root.mbStyle.fontPixelSize
		horizontalAlignment: Text.AlignHCenter
		color: root.mbStyle.textColor
		visible: devicesModel.rowCount == 0
		anchors.centerIn: parent
	}

	model: VesperaSafeDelegateModel {

		model: devicesModel

		delegate: MbSubMenu {
			id: discoveredDevice
			required property var model
			description: model.value

			property bool deviceAdded: false

			function onDeviceAddedCallback(added) {
				if (added !== undefined)
					deviceAdded = added
				return deviceAdded
			}

			subpage: Component {
					VesperaPageDiscoveredDevice {
						vesperaManager: root.vesperaManager
						serviceUid: discoveredDevice.model.buddy.uid
						port: discoveredDevice.model.value
						deviceAddedCallback: discoveredDevice.onDeviceAddedCallback}
				}
			}

	}
}