pragma ComponentBehavior: Bound

import QtQuick 2
import QtQuick.Layouts
import Victron.VenusOS

Page {
	id: root
	//% "Schedules"
	title:qsTrId("inetbox_schedules")

	property var inetboxModel
	property var indicatorColor

	GradientListView {
		id: settingsListView

		model: VisibleItemModel {

			ListNavigation {
				//% "Heating"
				text: qsTrId("inetbox_heating")
				onClicked: Global.pageManager.pushPage(scheduleSettingsComponent, {"title": text, type:"Heating"})
				indicatorColor:  (root.inetboxModel.schedulesStateItem.value & 1) !== 0 ? root.indicatorColor : 'transparent'
			}
			ListNavigation {
				//% "Water"
				text: qsTrId("inetbox_water")
				onClicked: Global.pageManager.pushPage(scheduleSettingsComponent, {"title": text, type:"Water"})
				indicatorColor:  (root.inetboxModel.schedulesStateItem.value & 2) !== 0 ? root.indicatorColor : 'transparent'
			}
			ListNavigation {
				//% "Aircon"
				text: qsTrId("inetbox_aircon")
				onClicked: Global.pageManager.pushPage(scheduleSettingsComponent, {"title": text, type:"Aircon"})
				indicatorColor:  (root.inetboxModel.schedulesStateItem.value & 4) !== 0 ? root.indicatorColor : 'transparent'
				preferredVisible: root.inetboxModel.showAircon
			}
		}
	}
	Component {
		id: scheduleSettingsComponent

		Page {
			id: scheduleSettings

			required property string type
			property string bindPrefix: root.inetboxModel.settingsPrefix + "/Schedules/" + type
			function buildUid(forType, endPath) {
				return type == forType ? bindPrefix + endPath : ""
			}

			Component.onCompleted: {
				if (type == "Heating") {
					temperatureSlider.from = 5
					temperatureSlider.to = 30
					temperatureSlider.dataItem.uid = buildUid(type, "/HeatingTargetTemp")
				} else if (type == "Aircon") {
					temperatureSlider.from = 16
					temperatureSlider.to = 31
					temperatureSlider.dataItem.uid = buildUid(type, "/AirconTargetTemp")
				}
			}

			GradientListView {

				model: VisibleItemModel {
					ListSwitch {
						//% "Enabled"
						text: qsTrId("inetbox_enabled")
						dataItem.uid: scheduleSettings.bindPrefix + "/Enabled"
					}

					ListTimeSelector {
						//% "Time"
						text: qsTrId("inetbox_time")
						dataItem.uid: scheduleSettings.bindPrefix + "/Time"
					}

					ListSwitch {
						//% "Repeat"
						text: qsTrId("inetbox_repeat")
						dataItem.uid: scheduleSettings.bindPrefix + "/Repeat"
						bottomInset: Theme.geometry_listItem_itemSeparator_height
					}

					ListItem {
						topPadding: topInset
						bottomPadding: bottomInset
						preferredVisible: scheduleSettings.type == "Heating" || scheduleSettings.type == "Aircon"

						contentItem: RowLayout {
							spacing: Theme.geometry_listItem_content_horizontalMargin

							Item {
								Layout.fillWidth: true
								Layout.alignment: Theme.screenSize === Theme.Portrait ? Qt.AlignBottom : Qt.AlignVCenter
								implicitHeight: temperatureSlider.implicitHeight

								ListSlider {
									id: temperatureSlider
									topInset: -topInset
									bottomInset: -bottomInset
									leftInset: -horizontalContentPadding // remove double inset
									rightInset: -horizontalContentPadding
									anchors.fill: parent
									//% "Temperature"
									text: qsTrId("inetbox_temperature")
									stepSize: 1
								}
							}

							QuantityLabel {
								font.pixelSize: 24
								value: temperatureSlider.value
								unit: Global.systemSettings.temperatureUnit
								Layout.minimumWidth: 60
								Layout.alignment: Theme.screenSize === Theme.Portrait ? Qt.AlignBottom : Qt.AlignVCenter
								Layout.bottomMargin: Theme.screenSize === Theme.Portrait ? Theme.geometry_listItem_content_verticalMargin : 0
							}
						}
					}

					ListRadioButtonGroup {
						preferredVisible: scheduleSettings.type == "Heating"
						//% "Heating mode"
						text: qsTrId("inetbox_heating_mode")
						defaultIndex: 0
						optionModel: root.inetboxModel.heatingModeModel
						dataItem.uid: scheduleSettings.buildUid("Heating", "/HeatingMode")
					}

					ListRadioButtonGroup {
						id: test
						preferredVisible: scheduleSettings.type == "Water"
						//% "Water mode"
						text: qsTrId("inetbox_water_mode")
						defaultIndex: 0
						optionModel: root.inetboxModel.waterModeModel
						dataItem.uid: scheduleSettings.buildUid("Water", "/WaterTargetTemp")
					}

					ListRadioButtonGroup {
						preferredVisible: scheduleSettings.type == "Aircon"
						//% "Aircon mode"
						text: qsTrId("inetbox_aircon_mode")
						defaultIndex: 0
						optionModel: root.inetboxModel.airconModeModel
						dataItem.uid: scheduleSettings.buildUid("Aircon", "/AirconMode")

					}

					ListRadioButtonGroup {
						preferredVisible: scheduleSettings.type == "Aircon"
						//% "Fan speed"
						text: qsTrId("inetbox_fan_speed")
						defaultIndex: 0
						optionModel: root.inetboxModel.airconFanSpeedModel
						dataItem.uid: scheduleSettings.buildUid("Aircon", "/AirconFanSpeed")
					}
				}
			}
		}
	}
}
