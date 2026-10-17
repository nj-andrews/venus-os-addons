import QtQuick 2
import com.victron.velib 1.0
import "utils.js" as Utils
import QtQuick.Controls

VesperaCustomOverviewPage {
	id: root

	//required by VesperaCustomOverviewPage
	source: "InetboxOverview.qml"

  property int headerFont: 20
	property int groupFont: 12
  property int textFont: 12

	property MbStyle mbStyle: MbStyle {}
	property MbStyle mbStyleSelected: MbStyle {isCurrentItem: true}

	property color backgroundColor: mbStyle.backgroundColor
	property color fontColor: mbStyle.textColor
	property color headerFontColor: mbStyle.textColor

	property color selectedTextColor: mbStyle.textColorSelected

	property color selectedColor: mbStyleSelected.backgroundColor
	property color groupBackgroundColor: backgroundColor
	property bool deviceValid: bindPrefix.length > 0

	//property color groupBorderColor: selectedColor
 	onSelectedColorChanged: {
		groupBackgroundColor = selectedColor
		groupBackgroundColor.a = 0.1
	}

	VBusItem { id: customNameItem; bind: Utils.path(bindPrefix, "/CustomName")}
	VBusItem { id: waterCurrentTempItem; bind: Utils.path(bindPrefix, "/Values/WaterCurrentTemp")}

	VBusItem { id: heatingTargetTempItem; bind: Utils.path(bindPrefix, "/Values/HeatingTargetTemp")}
	VBusItem { id: heatingCurrentTempItem; bind: Utils.path(bindPrefix, "/Values/HeatingCurrentTemp")}
	VBusItem { id: airconTargetTempItem; bind: Utils.path(bindPrefix, "/Values/AirconTargetTemp")}

	VBusItem { id: statusItem; bind: Utils.path(bindPrefix, "/Values/Status")}

	function formatTemp(value, round) {
		var num = parseFloat(value)
		if (!round)
			round = 0

		if (isNaN(num)) {
			return "--"
		}
		if (user.temperatureUnit === Unit.Fahrenheit) {
			return (num * 9 / 5 + 32).toFixed(round) + "°F"
		}
		return num.toFixed(round) + "°C"
	}

	Led {
		id: aliveLed
		value: item.valid && item.value == "ON" ? 1 : 0
		bind: Utils.path(bindPrefix, "/Values/Alive")
		onColor: "#58cf08"
		radius: 4
		anchors {
			top: parent.top
			topMargin: 9
			left: parent.left
			leftMargin: 6
		}
	}

	Text {
		text: statusItem?.value ?? ""
		font.pixelSize: root.textFont
		color: headerFontColor
		anchors {
			top: parent.top
			topMargin: 6
			left: aliveLed.right
			leftMargin: 6
		}
	}

	Text {
			id: header
			text: customNameItem.value || qsTr("Inetbox")
			color: headerFontColor
			font.pixelSize: headerFont
			//font.bold: true
			anchors {
				top: parent.top
				left: parent.left
				topMargin: 0
				horizontalCenter: parent.horizontalCenter
			}
			horizontalAlignment: Text.AlignHCenter
	}

	Text {
		id: heatingCurrentTempText
		text: formatTemp(heatingCurrentTempItem.value, 1)
		color: headerFontColor
		font.pixelSize: textFont
		anchors {
			top: parent.top
			topMargin: 6
			right: parent.right
			rightMargin: 6
		}
	}

	Text {
		text: "No Device Found"
		anchors.centerIn: parent
		visible: !deviceValid
	}

	// Water
	Rectangle {
		id: waterControlContainer
		visible: waterModeButtonControl.item.valid
		anchors {
			top: header.bottom
			topMargin: 2
			left: parent.left
			leftMargin: 8
		}
		width: parent.width / 2.2 - 16
		height: waterModeButtonControl.height + 40
		color: groupBackgroundColor
		//border {color: groupBorderColor;width: 1}
		radius: 12

		Text {
			text: "Water"
			color: fontColor
			font.pixelSize: groupFont
			//font.bold: true
			anchors {
				top: parent.top
				topMargin: 6
				left: parent.left
				leftMargin: 6
			}
		}

		ButtonGroupControl {
			id: waterModeButtonControl
			textColor: mbStyle.textColor
			selectedTextColor: root.selectedTextColor
			selectedColor: root.selectedColor
			bind: Utils.path(bindPrefix, "/Values/WaterTargetTemp")
			model: ["Off", "Eco", "Hot", "Boost"]
			valueMapping: ["0", "40.0", "60.0", "200.0"]
			anchors {
				top: parent.top
				topMargin: 30
				left: parent.left
				leftMargin: 6
				right: waterCurrentTempDisplay.left
				rightMargin: 6
			}

		}

		Text {
			id: waterCurrentTempDisplay
			text: formatTemp(waterCurrentTempItem.value)
			color: fontColor
			font.pixelSize: textFont
			anchors {
				top: parent.top
				topMargin: 6
				right: parent.right
				rightMargin: 6
			}

		}

	}
	// Energy Mix
	Rectangle {
		id: energyMixControlContainer
		visible: energyMixButtonControl.item.valid && energyMixButtonControl.item.value.length > 0
		anchors {
			top: waterControlContainer.top
			topMargin: waterControlContainer.topMargin
			left: waterControlContainer.right
			leftMargin: 8
		}
		width: parent.width / 1.8 - 12
		height: energyMixButtonControl.height + 40
		color: groupBackgroundColor
		//border {color: groupBorderColor;width: 1}
		radius: 12

		Text {
			text: "Energy Mix"
			color: fontColor
			font.pixelSize: groupFont
			//font.bold: true
			anchors {
				top: parent.top
				topMargin: 6
				left: parent.left
				leftMargin: 6
			}
		}

		ButtonGroupControl {
			id: energyMixButtonControl
			textColor: fontColor
			selectedTextColor: root.selectedTextColor
			selectedColor: root.selectedColor
			model: ["Gas", "Mix1", "Mix2", "El1", "El2"]
			valueMapping: ["Gas", "Mix1", "Mix2", "EL1", "EL2"]
			bind: Utils.path(bindPrefix, "/Values/EnergyMixCombined")
			anchors {
				left: parent.left
				leftMargin: 6
				right: parent.right
				rightMargin: 6
				top: parent.top
				topMargin: 30
			}
		}

	}

	// Heating
	Rectangle {
		id: heatingControlContainer
		visible: heatingButtonControl.item.valid && heatingButtonControl.item.value.length > 0
		anchors {
			top: waterControlContainer.bottom
			topMargin: 10
			left: parent.left
			leftMargin: 8
		}
		width: waterControlContainer.width
		height: heatingButtonControl.height + heatingSlider.height + 70
		color: groupBackgroundColor
		//border {color: groupBorderColor;width: 1}
		radius: 12

		Text {
			text: "Heating"
			color: fontColor
			font.pixelSize: groupFont
			//font.bold: true
			anchors {
				top: parent.top
				topMargin: 6
				left: parent.left
				leftMargin: 6
			}
		}

		ButtonGroupControl {
			id: heatingButtonControl
			textColor: fontColor
			selectedTextColor: root.selectedTextColor
			selectedColor: root.selectedColor
			model: ["Off", "Eco", "High"]
			valueMapping: ["off", "eco", "high"]
			bind: Utils.path(bindPrefix, "/Values/HeatingMode")
			anchors {
				left: parent.left
				leftMargin: 6
				right: parent.right
				rightMargin: 6
				top: parent.top
				topMargin: 30
			}
		}

		Text {
			text: "Target Temp"
			color: fontColor
			font.pixelSize: textFont
			anchors {
				top: heatingButtonControl.bottom
				topMargin: 10
				left: parent.left
				leftMargin: 6
			}
		}

		Slider {
			id: heatingSlider
			from: 5
			to: 30
			stepSize: 1
			snapMode: Slider.SnapAlways
			value: heatingTargetTempItem.value || 20
			onPressedChanged: if (!pressed) heatingTargetTempItem.setValue(value)
			background: Rectangle {
				x: heatingSlider.leftPadding
				y: heatingSlider.topPadding + heatingSlider.availableHeight / 2 - height / 2
				width: heatingSlider.availableWidth
				height: 6
				radius: 3
				color: Qt.rgba(root.selectedColor.r, root.selectedColor.g, root.selectedColor.b, 0.25)
				Rectangle {
					width: heatingSlider.visualPosition * parent.width
					height: parent.height
					radius: 3
					color: root.selectedColor
				}
			}
			anchors {
				left: parent.left
				leftMargin: 6
				right: tempValueLabel.left
				rightMargin: 4
				top: heatingButtonControl.bottom
				topMargin: 30

			}
	}

	Text {
		id: tempValueLabel
		text: formatTemp(heatingSlider.value)
		color: fontColor
		font.pixelSize: textFont
		anchors {
				right: parent.right
				rightMargin: 6
				top: heatingButtonControl.bottom
				topMargin: 29
				verticalCenter: heatingSlider.verticalCenter
		}
	}

}


// Aircon
Rectangle {
	id: airconControlContainer
	visible: airconModeButtonControl.item.valid && airconModeButtonControl.item.value.length > 0
	anchors {
		top: waterControlContainer.bottom
		topMargin: 10
		left: heatingControlContainer.right
		leftMargin: 8
	}
	width: energyMixControlContainer.width
	height: airconHeader.height + airconModeButtonControl.height + airconFanButtonControl.height + airconTargetTemp.height + airconSlider.height + 50
	color: groupBackgroundColor
	//border {color: groupBorderColor;width: 1}
	radius: 12

	Text {
		id: airconHeader
		text: "Aircon"
		color: fontColor
		font.pixelSize: groupFont
		//font.bold: true
		anchors {
			top: parent.top
			topMargin: 6
			left: parent.left
			leftMargin: 6
		}
	}

	ButtonGroupControl {
		id: airconModeButtonControl
		textColor: fontColor
		selectedTextColor: root.selectedTextColor
		selectedColor: root.selectedColor
		model: ["Off", "Vent", "Cool", "Hot", "Auto"]
		valueMapping: ["off", "vent", "cool", "hot", "auto"]
		bind: Utils.path(bindPrefix, "/Values/AirconMode")
		anchors {
			left: parent.left
			leftMargin: 6
			right: parent.right
			rightMargin: 6
			top: parent.top
			topMargin: 30
		}
	}


	ButtonGroupControl {
		id: airconFanButtonControl
		textColor: fontColor
		selectedTextColor: root.selectedTextColor
		selectedColor: root.selectedColor
		model: ["Low", "Mid", "High", "Night", "Auto"]
		valueMapping: ["low", "mid", "high", "night", "auto"]
		bind: Utils.path(bindPrefix, "/Values/AirconFanSpeed")
		anchors {
			left: parent.left
			leftMargin: 6
			right: parent.right
			rightMargin: 6
			top: airconModeButtonControl.bottom
			topMargin: 12
		}
	}


	Text {
		id: airconTargetTemp
		text: "Target Temp"
		color: fontColor
		font.pixelSize: textFont
		anchors {
			top: airconFanButtonControl.bottom
			topMargin: 10
			left: parent.left
			leftMargin: 6
		}
	}

	Slider {
		id: airconSlider
		from: 16
		to: 30
		stepSize: 1
		snapMode: Slider.SnapAlways
		value: airconTargetTempItem.value || 16
		onPressedChanged: if (!pressed) airconTargetTempItem.setValue(value)
		background: Rectangle {
			x: airconSlider.leftPadding
			y: airconSlider.topPadding + airconSlider.availableHeight / 2 - height / 2
			width: airconSlider.availableWidth
			height: 6
			radius: 3
			color: Qt.rgba(root.selectedColor.r, root.selectedColor.g, root.selectedColor.b, 0.25)
			Rectangle {
				width: airconSlider.visualPosition * parent.width
				height: parent.height
				radius: 3
				color: root.selectedColor
			}
		}
		anchors {
			left: parent.left
			leftMargin: 6
			right: airconTempValueLabel.left
			rightMargin: 4
			top: airconFanButtonControl.bottom
			topMargin: 30
		}
	}

	Text {
			id: airconTempValueLabel
			text: formatTemp(airconSlider.value)
			color: fontColor
			font.pixelSize: textFont
			anchors {
				leftMargin: 6
				right: parent.right
				rightMargin: 6
				top: airconFanButtonControl.bottom
				topMargin: 29
				verticalCenter: airconSlider.verticalCenter
			}
		}

	}

}
