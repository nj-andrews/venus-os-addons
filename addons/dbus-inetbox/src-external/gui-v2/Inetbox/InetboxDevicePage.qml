import QtQuick
import Victron.VenusOS

DevicePage {
	id: root

	InetboxModel {id: inetboxModel; serviceUid: root.serviceUid}

	settingsModel: VisibleItemModel {

		ListText {
			text: CommonWords.connected
			dataItem.uid: root.serviceUid + "/Connected"
			secondaryText: dataItem.valid && dataItem.value == 1 ? CommonWords.ok : "--"
		}

		ListTemperature {
			//% "Current Room Temperature"
			text: qsTrId("inetbox_room_current_temperature")
			dataItem.uid: root.serviceUid + "/Values/CurrentRoomTemp"
			decimals: 0
		}

		ListTemperature {
			//% "Target Room Temperature"
			text: qsTrId("inetbox_room_target_temperature")
			dataItem.uid: root.serviceUid + "/Values/HeatingTargetTemp"
			decimals: 0
		}

		ListTemperature {
			//% "Current Water Temperature"
			text: qsTrId("inetbox_water_current_temperature")
			dataItem.uid: root.serviceUid + "/Values/WaterCurrentTemp"
			decimals: 0
		}
		ListText {
			//% "Water"
			text: qsTrId("inetbox_water")
			dataItem.uid:  root.serviceUid + "/Values/WaterTargetTemp"
			secondaryText: inetboxModel.displayTextFromModelValue(inetboxModel.waterModeModel, dataItem.value)
		}

		ListText {
			//% "Heating mode"
			text: qsTrId("inetbox_heating_mode")
			dataItem.uid: root.serviceUid + "/Values/HeatingMode"
			secondaryText: inetboxModel.displayTextFromModelValue(inetboxModel.heatingModeModel, dataItem.value)
		}
		ListText {
			//% "Aircon mode"
			text: qsTrId("inetbox_aircon_mode")
			dataItem.uid: root.serviceUid + "/Values/HeatingMode"
			secondaryText: inetboxModel.displayTextFromModelValue(inetboxModel.airconModeModel, dataItem.value)
			preferredVisible: dataItem.valid
		}

		ListText {
			//% "Fan speed"
			text: qsTrId("inetbox_fan_speed")
			dataItem.uid: root.serviceUid + "/Values/AirconFanSpeed"
			secondaryText: inetboxModel.displayTextFromModelValue(inetboxModel.airconFanSpeedModel, dataItem.value)
			preferredVisible: dataItem.valid
		}

		ListNavigation {
			text: CommonWords.setup
			onClicked: {
				Global.pageManager.pushPage(inetboxSetupPage, {title: text, settingsPrefix: inetboxModel.settingsPrefix})
			}
		}
	}

	Component {
		id: inetboxSetupPage
		Page {
			id: root
			property string settingsPrefix
			GradientListView {
				model: VisibleItemModel {
					ListSwitch {
						id: showAircon
						//% "Show aircon"
						text: qsTrId("inetbox_show_aircon")
						dataItem.uid: root.settingsPrefix + "/ShowAircon"
					}
				}
			}

		}
	}
}
