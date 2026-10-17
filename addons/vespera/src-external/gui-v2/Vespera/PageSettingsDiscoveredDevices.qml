import QtQuick 2
import Victron.VenusOS
import "qrc:/Vespera/components" as Vespera

Page {
	id: root
	title: CommonWords.discovered_devices

	required property Vespera.VesperaManager vesperaManager
	property string devicesUid: vesperaManager.serviceUid + "/Discovered"
	property Vespera.ProgressText progressText
	property var popToPage

	Vespera.DbusChildModel {
		id: devicesModel
		uid: root.devicesUid
		childId: "Port"
		sortColumn: VeQItemTableModel.ValueColumn
	}
	Vespera.ProgressText {id:progressText}

 	GradientListView {
		id: listview
		header: PrimaryListLabel {
			horizontalAlignment: Text.AlignHCenter
			preferredVisible: root.progressText.running || listview.count ===0
			//% "No Usb devices discovered"
			text: root.progressText.running ? progressText.text : qsTrId("vespera_no_devices_discovered")
		}

		model: devicesModel

		delegate: ListNavigation {
			id: device
			required property var model

			text: CommonWords.device_info_title // "Device"
			secondaryText: model.value

			onClicked: Global.pageManager.pushPage("qrc:/Vespera/PageSettingsDiscoveredDevice.qml",
				{"title": text,
				vesperaManager: root.vesperaManager,
				port: model.value,
				serviceUid: model.buddy.uid}
			 )
		}
	}
}