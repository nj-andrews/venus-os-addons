import QtQuick 2
import com.victron.velib 1.0
import "utils.js" as Utils

MbPage {
	id: root
	title: "Vespera"

	property var vesperaManager: VesperaManager {
		id: vesperaManager
		toastNotifier: toast
	}

	Component.onDestruction: {
		if (vesperaManager)
			vesperaManager.cleanup()
	}

	model: VisibleItemModel {
		MbSubMenu {
			description: qsTrId("vespera_packages")
			subpage: Component { VesperaPageSettingsPackages {vesperaManager: root.vesperaManager} }
		}
		MbSubMenu {
			description: qsTrId("vespera_feeds")
			subpage: Component { VesperaPageSettingsFeeds {vesperaManager: root.vesperaManager} }
		}

		MbSubMenu {
			id:cdi
			description: qsTrId("vespera_custom_devices")
			subpage: Component {VesperaPageSettingsDevices {title:cdi.description; vesperaManager:root.vesperaManager} }
		}

		MbItemValue {
			description: qsTrId("vespera_version")
			item {
				bind: vesperaManager.serviceUid + "/ProductVersion"
				invalidate: false
			}
		}

		// MbSubMenu {
		// 	description: qsT("Settings")
		// 	subpage: Component { VesperaSettingsPage {} }
		// }

	}
}
