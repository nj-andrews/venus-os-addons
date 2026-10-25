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
		property alias font: button.font
		property alias cycleDelay: timer.interval
		property CycleButtonGroup group

		implicitHeight: button.height
		implicitWidth: valueLabel.x + valueLabel.width
		// value we wrote and are still waiting to see echoed back by the backend
		//property var _pendingValue: undefined

		icon.color: model === undefined
				? Theme.color_font_disabled
				: (model[currentIndex]?.color ?? Theme.color_font_primary)

		onCurrentValueChanged: {
			if (!model) return
			if (timer.running) return // user is mid-cycle; don't override their clicks
			//if (_pendingValue !== undefined) {
			//	if (currentValue != _pendingValue) return // stale echo of an earlier write
			//	_pendingValue = undefined
			//	pendingTimeout.stop()
			//}
			for (var i = 0; i < model.length; i++) {
				if (currentValue == model[i].value) {
					currentIndex = i
					break;
				}
			}
		}

		function updateBindingValue() {
			if (!binding || !model || currentIndex < 0 || currentIndex >= model.length)
				return
			//_pendingValue = model[currentIndex].value
			//pendingTimeout.restart()
			//binding.setValue(_pendingValue)
			binding.setValue(model[currentIndex].value)
		}

		// release the pending guard if the backend never echoes (e.g. rejected write)
		//Timer {
		//	id: pendingTimeout
		//	interval: 2000
		//	onTriggered: root._pendingValue = undefined
		//}

		Label {
			//% "Waiting for data..."
			text: qsTrId("inetbox_loading")
			visible: root.binding && !root.binding.valid
			anchors {fill: root}
		}

		Button {
			id: button
			flat: true
			font.pixelSize: root.group ? root.group.fontPixelSize : 24
			visible: !root.binding || root.binding.valid
			icon.height: font.pixelSize
			icon.width: font.pixelSize
			Timer {
				id: timer
				interval: 700
				onTriggered: root.updateBindingValue()
			}
			onClicked: {
				if (!root.model || root.model.length === 0) return
				timer.restart()
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
			font.pixelSize: root.font.pixelSize
			color: Theme.color_font_secondary
			width: root.group === undefined ? undefined: root.group.valueWidth
			anchors {
				left: root.group == undefined ? button.right : button.left
				leftMargin: root.group == undefined ? 0 : root.group._maxTextWidth + 10
				verticalCenter: button.verticalCenter
			}
		}
	}