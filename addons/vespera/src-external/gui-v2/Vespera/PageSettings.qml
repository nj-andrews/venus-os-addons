import QtQuick 2
import Victron.VenusOS

Page {
	id: root

	property real time: 0
	property int weekday: 6

	VeQuickItem {
		id: autoUpdateItem
		uid: Global.systemSettings.serviceUid + "/Settings/Vespera/AutoUpdate"
		onValueChanged: {
		const fields = String(value ?? "").trim().split(/\s+/)
		root.time = Number(fields[0]) || 0
		if (fields.length > 1 && fields[1] !== "")
			root.weekday = Number(fields[1])
		}
	}

	Component {
		id: timeSelectorComponent
		TimeSelectorDialog {
			onAccepted: autoUpdateItem.setValue(((hour * 3600) + (minute * 60)) + " " + root.weekday)
		}
	}

	GradientListView {
		model: VisibleItemModel {
				ListSwitch {
					id: autoUpdateSwitch
					checkable: true
					checked: String(autoUpdateItem.value ?? "") !== ""
					//% "Auto update packages (Sunday)"
					text: qsTrId("vespera_auto_update")
					writeAccessLevel: VenusOS.User_AccessType_SuperUser
					onClicked: { autoUpdateItem.setValue(checked ? root.time + " " + root.weekday : "") }
				}

				ListButton {
					text: CommonWords.locale_time
					enabled: autoUpdateSwitch.checked
					secondaryText: ClockTime.formatTime(Math.floor(root.time / 3600), Math.floor(root.time % 3600 / 60))
					onClicked: Global.dialogLayer.open(timeSelectorComponent, {
						hour: Math.floor(root.time / 3600),
						minute: Math.floor(root.time % 3600 / 60)
					})
				}
			}
    }
}