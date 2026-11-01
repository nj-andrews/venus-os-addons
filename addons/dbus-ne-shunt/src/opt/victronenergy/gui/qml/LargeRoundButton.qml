
import QtQuick 2.12
import QtQuick.Controls 2.12

Item {
	id: root
	property alias text: label.text
	property alias iconId: buttonIcon.iconId
	property bool checked: false
	property alias longPressDuration: mouseArea.pressAndHoldInterval
	property real holdProgress: 0
	property bool isLongPressMode: mouseArea.pressAndHoldInterval > 800

	property int diameter: 80
	property int outerBorderGap: 3
	property int outerBorderWidth: 2

	signal clicked()

	width: diameter + ((outerBorderGap + outerBorderWidth) * 2)
	height: width + label.height + 8

	Column {
		anchors.horizontalCenter: parent.horizontalCenter
		spacing: 8

		Item {
			id: circleContainer
			width: root.width
			height: root.width
			anchors.horizontalCenter: parent.horizontalCenter

			Rectangle {
				id: outerBorder
				anchors.fill: parent
				radius: width / 2
				color: "transparent"
				border.color: mbStyle.backgroundColor
				border.width: root.outerBorderWidth
			}

			Rectangle {
				id: buttonCircle
				width: root.diameter
				height: root.diameter
				radius: width / 2
				color: root.checked ? mbStyle.backgroundColor : "transparent"
				border.width: 0
				anchors.centerIn: parent

				Rectangle {
					anchors.fill: parent
					radius: width / 2
					color: "transparent"
					border.width: 2
					border.color: mbStyle.textColor
					opacity: root.isLongPressMode && mouseArea.pressed ? (0.2 + (0.8 * root.holdProgress)) : 0
				}

				MbIcon {
					id: buttonIcon
					anchors.centerIn: parent
					height: width
				}

				Text {
					anchors.horizontalCenter: parent.horizontalCenter
					anchors.bottom: parent.bottom
					anchors.bottomMargin: 4
					visible: root.isLongPressMode && mouseArea.pressed
					text: Math.max(0, Math.ceil((mouseArea.pressAndHoldInterval * (1 - root.holdProgress)) / 1000)) + "s"
					font.pixelSize: 10
					color: mbStyle.textColor
				}
			}

			Timer {
				id: holdProgressTimer
				interval: 50
				repeat: true
				running: false
				onTriggered: {
					if (!mouseArea.pressed || !root.isLongPressMode) {
						root.holdProgress = 0
						stop()
						return
					}

					root.holdProgress = Math.min(1, root.holdProgress + (interval / mouseArea.pressAndHoldInterval))
				}
			}

			MouseArea {
				id: mouseArea
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				//pressAndHoldInterval: root.longPressDuration
				onPressed: {
					if (root.isLongPressMode) {
						root.holdProgress = 0
						holdProgressTimer.start()
					}
				}
				onReleased: {
					if (root.isLongPressMode) {
						holdProgressTimer.stop()
						root.holdProgress = 0
					}
				}
				onCanceled: {
					if (root.isLongPressMode) {
						holdProgressTimer.stop()
						root.holdProgress = 0
					}
				}
				onClicked: {
					if (pressAndHoldInterval > 800)
						return

					checked = !checked
					root.clicked()
				}
				onPressAndHold: {
					if (pressAndHoldInterval <= 800)
						return

					holdProgressTimer.stop()
					root.holdProgress = 1

					checked = !checked
					root.clicked()
				}
			}
		}

		Text {
			id: label
			text: ""
			font.pixelSize: 12
			color: mbStyle.textColor
			horizontalAlignment: Text.AlignHCenter
			anchors.horizontalCenter: parent.horizontalCenter
		}
	}
}
