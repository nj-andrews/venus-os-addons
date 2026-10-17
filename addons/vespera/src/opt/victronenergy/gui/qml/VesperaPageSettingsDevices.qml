import QtQuick 2
import com.victron.velib 1.0

MbPage {
	id: root

	required property VesperaManager vesperaManager
	property string service: "com.victronenergy.vespera"
	property string settings: "com.victronenergy.settings/Settings/Vespera"
	function qsTrEx(str) { return qsTranslate("PageSettingsModbusDevices", str)}

	function scan() {
		if (vesperaManager.running)
			return

		progressText.start(qsTrEx("Scanning"))
		vesperaManager.usbScan(function (result) {
			progressText.stop()
		})
	}

	VesperaProgressText {id: progressText}

	model: VisibleItemModel {
		MbOK {
			id: scanItem
			description: qsTrEx("Scan for devices")
			value: progressText.running ? progressText.text : qsTrEx("Press to scan")
			onClicked: scan()
			show: userHasWriteAccess
		}

		MbSubMenu {
			id: savedDevices
			description: qsTrEx("Saved devices")
			item.value: subpage.model.count;
			subpage: VesperaPageSavedDevices {title: savedDevices.description; vesperaManager: root.vesperaManager}
		}

		MbSubMenu {
			id: discoveredDevices
			description: qsTrEx("Discovered devices")
			item.value: subpage.model.count
			subpage: VesperaPageDiscoveredDevices {
					title: discoveredDevices.description
					vesperaManager: root.vesperaManager
				}

		}
	}

}