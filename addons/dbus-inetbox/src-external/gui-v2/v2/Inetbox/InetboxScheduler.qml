import QtQuick 2
import QtQuick.Layouts
import Victron.VenusOS

Page {
	id: root
	//% "Scheduler"
	title:qsTrId("inetbox_scheduler")

	property var inetboxModel

	GradientListView {
		id: settingsListView

		model: VisibleItemModel {

			ListNavigation {
				//% "Heating"
				text: qsTrId("inetbox_heating")
				onClicked: Global.pageManager.pushPage(heatingSchedule, {"title": text})
			}
			ListNavigation {
				//% "Water"
				text: qsTrId("inetbox_water")
				onClicked: Global.pageManager.pushPage(waterSchedule, {"title": text})
			}
			ListNavigation {
				//% "Aircon"
				text: qsTrId("inetbox_aircon")
				onClicked: Global.pageManager.pushPage(airconSchedule, {"title": text})
			}
		}
	}
	Component {
		id: heatingSchedule

		Page {

			GradientListView {
				id: settingsListView

				model: VisibleItemModel {
					ListSwitch {
						//% "Enabled"
						text: qsTrId("inetbox_enabled")
					}

					//ListChargeSchedule
					ListItem {
						topPadding: topInset
						bottomPadding: bottomInset

						contentItem: RowLayout {
							spacing: Theme.geometry_listItem_content_horizontalMargin

							Item {
								Layout.fillWidth: true
								Layout.alignment: Qt.AlignVCenter
								implicitHeight: heatingTempSlider.implicitHeight

								ListSlider {
									id: heatingTempSlider
									topInset: -topInset
									bottomInset: -bottomInset
									leftInset: -horizontalContentPadding // remove double index
									rightInset: -horizontalContentPadding
									anchors.fill: parent
									//% "Temperature"
									text: qsTrId("inetbox_temperature")
									dataItem.uid: inetboxModel.heatingTargetTempItem.uid
									from: 5; to: 30
									stepSize: 1
								}
							}

							QuantityLabel {
								id: tempLabel
								font.pixelSize: 24
								value: heatingTempSlider.value
								unit: Global.systemSettings.temperatureUnit
								unitColor: Theme.color_overviewPage_widget_battery_font_secondary
								Layout.minimumWidth: 50
								Layout.maximumWidth: 50
								Layout.alignment: Qt.AlignVCenter
							}
						}
					}

					ListRadioButtonGroup {
						//% "Heating mode"
						text: qsTrId("inetbox_heating_mode")
						optionModel: inetboxModel.heatingModeModel
						dataItem.uid: inetboxModel.heatingModeItem.uid
						currentIndex: 1
						// onOptionClicked: function(index) {
						// 	currentIndex = index
						// }
					}
					ListTimeSelector {
						text: "Time"
					}
					ListSwitch {
						//% "Repeat"
						text: qsTrId("inetbox_repeat")
					}
				}
			}
		}

	}

	Component {
		id: waterSchedule
		Page {
			GradientListView {
				id: settingsListView

				model: VisibleItemModel {
				}
			}
		}
	}
		Component {
		id: airconSchedule
		Page {
			GradientListView {
				id: settingsListView

				model: VisibleItemModel {
				}
			}
		}
	}
}
