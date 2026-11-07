import QtQuick
import QtQuick.Controls.impl as CP
import QtQuick.Templates as T
import QtQuick.Shapes
import QtQuick.Layouts
import QtQuick.Controls as QCTL

Rectangle {
	id: root
	color: "black"
	anchors.fill: parent

	property int buttonOffsetX: 20
	property int buttonOffsetY: 10
	property real xOffset: 1.2

	property bool heatingOn: heatingButton.currentItem.value != "off"
	property bool airconOn: airconModeButton.currentItem.value != "off"
	property real airconValue: 17
	property real heatingValue: 22

	property string dummySvg: "data:image/svg+xml;utf8," + "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'>" + "<circle cx='15' cy='15' r='14' fill='#3498db' stroke='#FF0000' stroke-width='2'/>" + "</svg>"

	Item {
		CycleButtonGroup { id: cycleButtonGroup}
		// Water
		CycleButton {
			id: waterButton
			icon.source: root.dummySvg
			group: cycleButtonGroup

			//% "Water"
			text: "Water"
			secondaryText: "42°"
			anchors {
				left: parent.left
				leftMargin: 20
				top: parent.top

			}

			model: [{
					"value": "0",
					"display": "Off",
					"color": "grey"
				}, {
					"value": "40.0",
					"display": "Eco",
					"color": "green"
				}, {
					"value": "60.0",
					"display": "Hot",
					"color": "green"
				}, {
					"value": "200.0",
					"display": "Boost",
					"color": "green"
				}]
		}
		// Heating
		CycleButton {
			id: heatingButton
			icon.source: root.dummySvg
			group: cycleButtonGroup

			//% "Heating"
			text: "Heating"
			anchors {
				left: waterButton.left
				leftMargin: root.buttonOffsetX
				top: waterButton.bottom
				topMargin: root.buttonOffsetY
			}
			model: [{
					"value": "off",
					"display": "Off",
					"secondaryText": "Hello",
					"color": "grey"
				}, {
					"value": "green",
					"display": "Eco",
					"color": "green"
				}, {
					"value": "green",
					"display": "High",
					"color": "green"
				}]

			onCurrentIndexChanged: {
				if (model[currentIndex].value !== "off" && airconModeButton.currentItem.value !== "off") {
					airconModeButton.currentIndex = 0;
				}
			}
		}
		// Aircon mode
		CycleButton {
			id: airconModeButton
			icon.source: root.dummySvg
			group: cycleButtonGroup
			//statusText2: "16°"
			//% "Aircon"
			text: "Aircon"
			anchors {
				left: heatingButton.left
				leftMargin: root.buttonOffsetX
				top: heatingButton.bottom
				topMargin: root.buttonOffsetY
			}
			model: [{
					"value": "off",
					"display": "Off",
					"color": "grey"
				}, {
					"value": "green",
					"display": "Cool",
					"color": "green"
				}, {
					"value": "vent",
					"display": "Vent",
					"color": "green"
				}, {
					"value": "hot",
					"display": "Hot",
					"color": "green"
				}, {
					"value": "auto",
					"display": "Auto",
					"color": "green"
				}]

			onCurrentIndexChanged: {
				if (model[currentIndex].value !== "off" && heatingButton.currentItem.value !== "off") {
					heatingButton.currentIndex = 0;
				}
			}
		}
		// Aircon Fan Speed
		CycleButton {
			id: airconFanSpeedButton
			icon.source: root.dummySvg
			group: cycleButtonGroup

			//% "Fan speed"
			text: "Fan speed"
			anchors {
				left: airconModeButton.right
				top: airconModeButton.top
			}
			model: [{
					"value": "low",
					"display": "Low",
					"color": "white"
				}, {
					"value": "mid",
					"display": "Mid",
					"color": "white"
				}, {
					"value": "high",
					"display": "High",
					"color": "white"
				}, {
					"value": "night",
					"display": "Night",
					"color": "white"
				}, {
					"value": "auto",
					"display": "Auto",
					"color": "lightseagreen"
				}]
		}
		// EnergyMix
		CycleButton {
			id: energyMixButton
			icon.source: root.dummySvg
			group: cycleButtonGroup
			//% "Energy Mix"
			text: "Energy Mix"

			anchors {
				left: airconModeButton.left
				leftMargin: root.buttonOffsetX //* root.xOffset
				top: airconModeButton.bottom
				topMargin: root.buttonOffsetY
			}
			model: [{
					"value": "gas",
					"display": "Gas",
					"color": '#ffab03'
				}, {
					"value": "mix1",
					"display": "Mix1",
					"color": "green"
				}, {
					"value": "mix2",
					"display": "Mix2",
					"color": "green"
				}, {
					"value": "el1",
					"display": "El1",
					"color": "lightskyblue"
				}, {
					"display": "El2",
					"color": "lightskyblue"
				}]
		}

		anchors {
			fill: parent
			leftMargin: 20
			topMargin: 20
		}
	}

	component CycleButtonGroup : QtObject {
		property real _maxTextWidth: 0
		property real valueWidth: 60
		property real secondaryWidth: 40
	}

	component CycleButton: Item {
		id: control

		property int currentIndex
		property var currentItem: model[currentIndex]
		property alias icon: button.icon
		property var model: []

		property alias text: button.text
		property alias display: valueLabel.text
		property alias secondaryText: secondaryLabel.text
		property alias valueColor: valueLabel.color
		property alias secondaryColor: secondaryLabel.color

		property CycleButtonGroup group

		//property alias color: button.color
		implicitHeight: button.height
		implicitWidth: secondaryLabel.x + secondaryLabel.width
		icon.color: control.model[control.currentIndex].color

		Button {
			id: button
			flat: true

			onClicked: {
				control.currentIndex = (control.currentIndex === control.model.length - 1) ? 0 : control.currentIndex + 1;
			}

			anchors {
				left: parent.left
				verticalCenter: parent.verticalCenter
			}
			onImplicitWidthChanged: {
				if (control.group === undefined) return
				if (implicitWidth > control.group._maxTextWidth)
					control.group._maxTextWidth = implicitWidth;
			}
		}
		Label {
			id: valueLabel
			color: "dimgray"
			text: control.model[control.currentIndex].display ?? ""

			width: control.group === undefined ? undefined: control.group.valueWidth
			anchors {
				left: control.group == undefined ? button.right : button.left
				leftMargin: control.group == undefined ? 0 : control.group._maxTextWidth + 10
				verticalCenter: button.verticalCenter
			}
		}
		Label {
			id: secondaryLabel
			color: "dimgray"
			text: control.model[control.currentIndex].secondaryText ?? ""
			width: control.group === undefined ? undefined: control.group.secondaryWidth
			anchors {
				left: valueLabel.right
				leftMargin: 10
				top: valueLabel.top
			}
		}
	}

	component Button: QCTL.Button {
		id: root

		// 1. Core button sizing binds to the contentItem's implicit size
		width: contentItem.implicitWidth + leftPadding + rightPadding
		height: contentItem.implicitHeight + topPadding + bottomPadding

		contentItem: Item {
			// 2. Dynamically calculate implicit size based on display mode
			implicitWidth: root.display === T.AbstractButton.TextUnderIcon ? Math.max(contentLabel.implicitWidth, contentIcon.implicitWidth) : contentLabel.implicitWidth + contentIcon.implicitWidth + (contentLabel.text && contentIcon.source.toString() ? root.spacing : 0)

			implicitHeight: root.display === T.AbstractButton.TextUnderIcon ? contentLabel.implicitHeight + contentIcon.implicitHeight + (contentLabel.text && contentIcon.source.toString() ? root.spacing : 0) : Math.max(contentLabel.implicitHeight, contentIcon.implicitHeight)

			Label {
				id: contentLabel

				// Positioning relative to icon layout
				x: root.display === T.AbstractButton.TextBesideIcon ? (contentIcon.visible ? contentIcon.width + root.spacing : 0) : (parent.width - width) / 2
				y: root.display === T.AbstractButton.TextUnderIcon ? (contentIcon.visible ? contentIcon.height + root.spacing : 0) : (parent.height - height) / 2

				horizontalAlignment: Text.AlignHCenter
				verticalAlignment: Text.AlignVCenter

				text: root.text
				color: "white"
				font: root.font
				visible: root.display !== T.AbstractButton.IconOnly
				elide: Text.ElideRight
			}

			CP.ColorImage {
				id: contentIcon

				x: root.display === T.AbstractButton.TextBesideIcon ? 0 : (parent.width - width) / 2
				y: root.display === T.AbstractButton.TextUnderIcon ? 0 : (parent.height - height) / 2

				width: root.icon.width || 32
				height: root.icon.height || 32
				source: root.icon.source
				color: root.icon.color
				visible: root.display !== T.AbstractButton.TextOnly
			}
		}
	}

	component Label: Text {
	}
}
