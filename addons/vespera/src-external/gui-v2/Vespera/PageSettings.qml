import QtQuick 2
import Victron.VenusOS

Page {
	id: page

	// VeQuickItem {
	// 	id: autoUpdateItem
	// 	uid: "/Settings/Vespera/AutoUpdate"
	// }

	GradientListView {
		id: settingsListView

		model: VisibleItemModel {
			ListSwitch {
				id: autoUpdateSwitch
				checkable: true
				checked: timeSelector.dataItem.value != ""
				//% "Auto update packages (Sunday)"
				text: qsTrId("vespera_auto_update")
				writeAccessLevel: VenusOS.User_AccessType_SuperUser
				onClicked: {
					if (timeSelector.dataItem.value != "")
						timeSelector.dataItem.setValue("")
				}
			}

			ListTimeSelector {
				id: timeSelector
				text: "Time"
				enabled: autoUpdateSwitch.checked
				dataItem.uid: Global.systemSettings.serviceUid + "/Settings/Vespera/AutoUpdate"
			}

		}
	}
}