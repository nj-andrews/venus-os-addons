import QtQuick
import Victron.VenusOS

DevicePage {
	id: root
	serviceUid: bindPrefix

	property string bindPrefix

	InetboxModel {id: inetboxModel; serviceUid: root.bindPrefix}


	settingsModel: VisibleItemModel {

		ListText {
			//% "Connected"
			text: qsTrId("inetbox_connected")
			dataItem.uid: root.bindPrefix + "/Connected"
			secondaryText: dataItem.valid && dataItem.value == 1 ? CommonWords.ok : "--"
		}

		ListTemperature {
			//% "Current Room Temperature"
			text: qsTrId("inetbox_room_current_temperature")
			dataItem.uid: root.bindPrefix + "/Values/CurrentRoomTemp"
			decimals: 0
		}

		ListTemperature {
			//% "Target Room Temperature"
			text: qsTrId("inetbox_room_target_temperature")
			dataItem.uid: root.bindPrefix + "/Values/HeatingTargetTemp"
			decimals: 0
		}

		ListTemperature {
			//% "Current Water Temperature"
			text: qsTrId("inetbox_water_current_temperature")
			dataItem.uid: root.bindPrefix + "/Values/WaterCurrentTemp"
			decimals: 0
		}
		ListText {
			//% "Water"
			text: qsTrId("inetbox_water")
			dataItem.uid:  root.bindPrefix + "/Values/WaterTargetTemp"
			secondaryText: inetboxModel.displayTextFromModelValue(inetboxModel.waterModeModel, dataItem.value)
		}

		ListText {
			//% "Heating"
			text: qsTrId("inetbox_heating")
			dataItem.uid: root.bindPrefix + "/Values/HeatingMode"
			secondaryText: inetboxModel.displayTextFromModelValue(inetboxModel.heatingModeModel, dataItem.value)
		}
		ListText {
			//% "Aircon"
			text: qsTrId("inetbox_aircon")
			dataItem.uid: root.bindPrefix + "/Values/HeatingMode"
			secondaryText: inetboxModel.displayTextFromModelValue(inetboxModel.airconModeModel, dataItem.value)
			preferredVisible: dataItem.valid
		}

		ListText {
			//% "Fan speed"
			text: qsTrId("inetbox_fan_speed")
			dataItem.uid: root.bindPrefix + "/Values/AirconFanSpeed"
			secondaryText: inetboxModel.displayTextFromModelValue(inetboxModel.airconFanSpeedModel, dataItem.value)
			preferredVisible: dataItem.valid
		}

		ListNavigation {
			text: CommonWords.setup
			onClicked: {
				Global.pageManager.pushPage(inetboxSetupPage)
			}
		}
	}

	Component {
		id: inetboxSetupPage
		Page {
			id: root

			GradientListView {
				model: VisibleItemModel {
					ListSwitch {
						id: showAircon
						//% "Show aircon"
						text: qsTrId("inetbox_show_aircon")
						dataItem.uid: inetboxModel.settingsPrefix + "/ShowAircon"
					}
				}
			}

		}
	}
}
