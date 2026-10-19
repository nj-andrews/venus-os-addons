import QtQuick
import Victron.VenusOS

Item {
		id: root

    property VeQuickItem binding
    property int currentIndex
    readonly property var currentValue: binding?.value

		property alias icon: button.icon
		property var model: []

		property alias text: button.text
		property alias display: valueLabel.text

		property alias valueColor: valueLabel.color
		property real fontPixelSize: 24
		property alias cycleDelay: timer.interval
		property CycleButtonGroup group

		implicitHeight: button.height
		implicitWidth: valueLabel.x + valueLabel.width
		icon.color: model === undefined
				? Theme.color_font_disabled
				: model[currentIndex].color
					? model[currentIndex].color
					: Theme.color_font_primary

		icon.height: 24
		icon.width: 24

		onCurrentIndexChanged: {
			if (!model || currentIndex < 0 || currentIndex >= model.length)
				return
			if (!timer.running)
				updateBindingValue()
		}

		onCurrentValueChanged: {
			if (!model) return
			for (var i = 0; i < model.length; i++) {
				if (currentValue == model[i].value) {
					currentIndex = i
					break;
				}
			}
		}
		// function setCurrentIndex(index) {
		// 	if (currentIndex < 0 || currentIndex >= model.length)
		// 		return
		// 	currentIndex = index
		// }

		function updateBindingValue() {
			if (!binding || !model || currentIndex < 0 || currentIndex >= model.length)
				return
			binding.setValue(model[currentIndex].value)
		}

		Label {
			//% "Waiting for data..."
			text: qsTrId("inetbox_loading")
			visible: root.binding && !root.binding.valid
			anchors {fill: root}
		}

		Button {
			id: button
			flat: true
			font.pixelSize: root.fontPixelSize
			visible: !root.binding || root.binding.valid

			Timer {
				id: timer
				interval: 700
				onTriggered: root.updateBindingValue()
			}
			onClicked: {
				timer.restart() //keep before setting currentIndex
				root.currentIndex = (root.currentIndex === root.model.length - 1)
					? 0 : root.currentIndex + 1;
			}

			anchors {
				left: parent.left
				verticalCenter: parent.verticalCenter
			}
			onImplicitWidthChanged: {
				if (root.group === undefined) return
				if (implicitWidth > root.group._maxTextWidth)
					root.group._maxTextWidth = implicitWidth;
			}
		}

		Label {
			id: valueLabel
			visible: !root.binding || root.binding.valid
			text: root.model[root.currentIndex].display ?? ""
			font.pixelSize: root.fontPixelSize
			color: Theme.color_font_secondary
			width: root.group === undefined ? undefined: root.group.valueWidth
			anchors {
				left: root.group == undefined ? button.right : button.left
				leftMargin: root.group == undefined ? 0 : root.group._maxTextWidth + 10
				verticalCenter: button.verticalCenter
			}
		}
	}