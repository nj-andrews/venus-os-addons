import QtQuick 2.15
import QtQuick.Templates 2.15 as T
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Rectangle {
	id: rt

	color: "black"
	anchors.fill: parent

	property real maxTankLabelWidth: 0

	Item {

		Text {
			y: temp.y - 120
			x: temp.x + 80
			text: temp.value
			color: "white"
		}
		MinimalSlider {
			id: temp
			anchors.top: parent.top
			anchors.topMargin: 200

			from: 5
			to: 32
			stepSize: 1

			//angle: 250 // Slanted 25 degrees

			//onValueChanged: console.log("Value changed to:", value)
		}

		anchors {
			fill: parent
			leftMargin: 5
			topMargin: 5
		}
	}

	component MinimalSlider: T.Slider {
		id: root

		property real angle: 0
		//property color trackColor: "#E0E0E0"
		property color progressColor: "#2196F3"
		property color handleColor: '#ff1e88e5'
		property color handlePressedColor: "#ff1565C0"
		property color tickColor: '#ffffff'

		property bool hideProgress: true
		property bool hideTicks: true

		property real tickThickness: 2
		property real tickLength: tickThickness
		property real tickRadius: tickLength / 2
		property real tickAngle: 0

		property real handleDiameter: 24
		property real trackThickness: 2

		// Default sizing
		implicitWidth: Math.max(implicitBackgroundWidth + leftPadding + rightPadding, implicitHandleWidth + leftPadding + rightPadding)
		implicitHeight: Math.max(implicitBackgroundHeight + topPadding + bottomPadding, implicitHandleHeight + topPadding + bottomPadding)

		// Reserve horizontal padding so the circle handle doesn't clip at min/max edges
		padding: 0
		leftPadding: handleDiameter / 2
		rightPadding: handleDiameter / 2

		// Apply rotation slant around center
		transformOrigin: Item.Center
		rotation: angle

		// --- Track / Background Delegate ---
		background: Item {
			x: root.leftPadding
			y: root.topPadding + root.availableHeight / 2 - height / 2
			implicitWidth: 200 // default width
			implicitHeight: root.trackThickness
			width: root.availableWidth
			height: implicitHeight

			// Active Progress Fill
			Rectangle {
				width: root.visualPosition * parent.width
				height: parent.height
				color: root.progressColor

				opacity: root.hideProgress ? (root.pressed ? 1.0 : 0.0) : 1.0
				Behavior on opacity  {
					enabled: root.hideProgress
					NumberAnimation {
						duration: root.pressed ? 2000 : 150
						// Optional: Easing curves make the transition feel even smoother
						easing.type: root.pressed ? Easing.OutCubic : Easing.InQuad
					}
				}
			}

			// Tick Marks (Visible when slider is pressed)
			Item {
				anchors.fill: parent

				opacity: root.hideTicks ? (root.pressed ? 1.0 : 0.0) : 1.0
				Behavior on opacity  {
					enabled: root.hideTicks
					NumberAnimation {
						duration: root.pressed ? 2000 : 150
						// Optional: Easing curves make the transition feel even smoother
						easing.type: root.pressed ? Easing.OutCubic : Easing.InQuad
					}
				}

				Repeater {
					model: (root.stepSize > 0 && root.to > root.from) ? Math.floor((root.to - root.from) / root.stepSize) + 1 : 0

					delegate: Rectangle {
						id: tick
						rotation: root.tickAngle
						transformOrigin: Item.Center
						required property int index
						property real range: root.to - root.from
						property real fraction: range > 0 ? (index * root.stepSize) / range : 0

						x: fraction * parent.width - (width / 2)
						anchors.verticalCenter: parent.verticalCenter
						width: root.tickThickness
						height: root.tickLength
						color: root.tickColor
						radius: root.tickThickness
					}
				}
			}
		}

		// --- Circular Handle Delegate ---
		handle: Item {
				implicitWidth: root.handleDiameter
				implicitHeight: root.handleDiameter
			Rectangle {
				id: original
				x: root.leftPadding + root.visualPosition * root.availableWidth - width / 2
				y: root.topPadding + root.availableHeight / 2 - height / 2
				implicitWidth: root.handleDiameter
				implicitHeight: root.handleDiameter
				radius: width / 2
				color: root.pressed ? root.handlePressedColor : root.handleColor

				border.color: "#FFFFFF"
				border.width: 2
			}
			Item {
				id: reflection
				x: original.x
				y: original.height + 3
				width: original.width
				height: original.height
				opacity: .5

				Rectangle {
					id: reflectionMask

					width: original.width
					height: original.height
					radius: original.radius

					gradient: Gradient {
						GradientStop {
							position: 0.0
							color: '#ffffffff'
						}
						GradientStop {
							position: .8
							color: "#00ffffff"
						}
					}
				}
				Rectangle {
					id: reflectionMask3
					x: 2
					y: 2
					width: original.width -4
					height: original.height -4
					radius: original.radius

					gradient: Gradient {
						GradientStop {
							position: 0.0
							color: '#ff000000'
						}
						GradientStop {
							position: .8
							color: "#00000000"
						}
					}
				}
				Rectangle {
					id: reflectionMask2
					x: 2
					y: 2
					width: original.width -4
					height: original.height -4
					radius: original.radius

					gradient: Gradient {
						GradientStop {
							position: 0.0
							color: '#1e88e5'
						}
						GradientStop {
							position: 0.8
							color: "#00ffffff"
						}
					}
				}
			}
		}
	}
}
