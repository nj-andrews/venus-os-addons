import QtQuick
import QtQuick.Layouts
import Victron.VenusOS
import QtQuick.Controls.impl as CP

Rectangle {
	id: root

	color: Theme.color_background_secondary
	radius: Theme.geometry_button_radius
	implicitHeight: inetboxColumn.implicitHeight + inetboxColumn.anchors.margins * 2
	property alias targetTemperatureSlider: targetTemperatureSlider
	property var model
	property real buttonOffsetX: 0


	//No device detected loader
	Loader {
		active: root.model.device === null
		anchors.centerIn: parent
		sourceComponent: Component {
			ColumnLayout {
				Label {
					//% "No Inetbox device found"
					text: qsTrId("inetbox_no_device_found")
					Layout.alignment: Qt.AlignHCenter
					Layout.bottomMargin: 10
				}

				ListItemButton {
					//% "Click to install device"
					text: qsTrId("inetbox_click_to_install_device")
					Layout.alignment: Qt.AlignHCenter
					onClicked:  {
						Global.pageManager.pushPage("qrc:/Vespera/PageSettingsDevicesList.qml")
					}
				}
			}
		}
	}
	// Error Description loader
	Loader {
		id: errorLoader
		active: root.model.device !== null && root.model.hasError && root.model.seenError != root.model.errorCodeItem.value
		anchors.centerIn: parent
		anchors.verticalCenterOffset: 30
		sourceComponent: Component {

			Row {
				spacing: Theme.geometry_modalWarningDialog_description_spacing

				CP.IconImage {
					id: alarmIcon
					source: "qrc:/images/icon_alarm_48.svg"
					color: Theme.color_warning
					anchors.verticalCenter: errorInfo.verticalCenter
				}
				ColumnLayout {
					id: errorInfo

					Label {
						id: description
						font.pixelSize: Theme.font_size_body2
						//: %1 = error code
						//% "Error Code: %1"
						text: qsTrId("inetbox_error_code").arg(root.model.errorCodeItem.value)
					}
					Label {
						text: (root.model.errorDescriptionItem.value ?? "").replace(/\|/g, "\n")
						wrapMode: Text.WordWrap
						Layout.preferredWidth: Math.min(500, implicitWidth)
					}
					// ListItemButton {
					// 	//% "Close"
					// 	text: qsTrId("inetbox_close")
					// 	Layout.preferredWidth: Math.min(100, implicitWidth)
					// 	Layout.alignment: Qt.AlignHCenter

					// 	onClicked:  {
					// 		root.model.seenError=root.model.errorCodeItem.value
					// 	}
					// }
				}

			}
		}
	}

	ColumnLayout {
		id: inetboxColumn
		anchors.fill: parent
		anchors.margins: 4
		visible: root.model.device !== null && !errorLoader.active

		// Room Temps
		RowLayout {
			id: mainTemps
			spacing: 10
			QuantityLabel {
				id: tempValue
				font.pixelSize: Theme.screenSize === Theme.Portrait ? 36 : 44
				alignment: Qt.AlignBottom
				Layout.alignment: Qt.AlignBottom
				unit: Global.systemSettings.temperatureUnit
				value: root.model.currentTemperatureItem.value ?? NaN
			}

			QuantityLabel {
				font.pixelSize: tempValue.font.pixelSize / 2
				alignment: Qt.AlignBottom
				Layout.alignment: Qt.AlignBottom
				Layout.bottomMargin: 5 // HACK QuantityLabel does not expose baseline
				Layout.rightMargin: -10
				value: targetTemperatureSlider.pressed ? targetTemperatureSlider.value : root.model.targetTemperature ?? NaN
				visible: root.model.heatingOn | root.model.airconOn
				unit: Global.systemSettings.temperatureUnit
				unitColor: Theme.color_overviewPage_widget_battery_font_secondary
				Layout.minimumWidth: 60
			}

			MinimalSlider {
				id: targetTemperatureSlider
				hideTicks: false
				visible: root.model.heatingOn || root.model.airconOn
				value: root.model.targetTemperature
				Layout.alignment: Qt.AlignVCenter
				Layout.fillWidth: true

				onPressedChanged: {
					if (!pressed) // only update when button is released
						root.model.updateTargetTemperature(value);
				}
				from: root.model.heatingOn ? 5 : 16
				to: root.model.heatingOn ? 30 : 31
				stepSize: 1
			}
		}

		CycleButtonGroup { id: cycleButtonGroup }

		// Water
		RowLayout {
			id: waterRow
			Layout.topMargin: 10
			Layout.leftMargin: mainTemps.x + root.buttonOffsetX
			CycleButton {
				id: waterHeaterCycleButton
				group: cycleButtonGroup
				icon.source: "qrc:/Inetbox/images/freshwater.svg"
				binding: root.model.waterTargetTemperatureItem
				model: root.model.waterModeModel
				//% "Water"
				text: qsTrId("inetbox_water")
			}
			QuantityLabel {
				//id: waterHeaterCurrentTemperature
				font.pixelSize: 24
				visible: root.model.waterCurrentTemperatureItem.valid
				unit: Global.systemSettings.temperatureUnit
				value: root.model.waterCurrentTemperatureItem.value ?? NaN
				Layout.leftMargin: Theme.screenSize === Theme.Portrait ? 0 : 40
			}
		}

		// Heating
		CycleButton {
			id: heatingCycleButton
			group: cycleButtonGroup
			icon.source: "qrc:/Inetbox/images/heating.svg"
			binding: root.model.heatingModeItem
			model: root.model.heatingModeModel
			//% "Heating"
			text: qsTrId("inetbox_heating")
			Layout.leftMargin: waterRow.x + root.buttonOffsetX
		}

		// Aircon mode
		RowLayout {
			CycleButton {
				id: airconModeCycleButton
				group: cycleButtonGroup
				icon.source: "qrc:/Inetbox/images/aircon.svg"
				binding: root.model.airconModeItem
				model: root.model.airconModeModel
				visible: root.model.showAircon
				//% "Aircon"
				text: qsTrId("inetbox_aircon")
				Layout.leftMargin: heatingCycleButton.x + root.buttonOffsetX
			}
			Loader {
				active: root.model.showAircon && Theme.screenSize !== Theme.Portrait
				// needed incase showAircon was previously true
				Layout.preferredHeight: !root.model?.showAircon ? 0 : implicitHeight
				Layout.leftMargin: 40
				sourceComponent: airconFanSpeedCycleButtonFactory
			}
		}

		//Aircon Fan (changes location based on orientation)
		Loader {
			active: root.model.showAircon && Theme.screenSize === Theme.Portrait
			Layout.preferredHeight: !root.model?.showAircon ? 0 : implicitHeight
			Layout.leftMargin: 40
			sourceComponent: airconFanSpeedCycleButtonFactory
		}

		Component {
			id: airconFanSpeedCycleButtonFactory
			// Aircon Fan Speed
			CycleButton {
				id: airconFanSpeedCycleButton
				group: cycleButtonGroup
				visible: root.model.airconFanSpeedItem.valid
				icon.source: "qrc:/Inetbox/images/fan.svg"
				icon.color: airconModeCycleButton.icon.color
				binding: root.model.airconFanSpeedItem
				model: root.model.airconFanSpeedModel

				//% "Fan speed"
				text: qsTrId("inetbox_fan_speed")
			}
		}
		// EnergyMix
		CycleButton {
			id: energyMixButton
			group: cycleButtonGroup
			icon.source: "qrc:/Inetbox/images/energy_mix.svg"
			binding: root.model.energyMixItem
			model: root.model.energyMixModel
			//% "Energy Mix"
			text: qsTrId("inetbox_energy_mix")
			Layout.leftMargin: (root.model.showAircon
				? airconModeCycleButton.x
				: heatingCycleButton.x) + root.buttonOffsetX

		}



	}
}
