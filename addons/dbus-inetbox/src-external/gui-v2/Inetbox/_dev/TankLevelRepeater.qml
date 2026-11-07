import QtQuick 2.15
import QtQuick.Templates 2.15 as T
import QtQuick.Controls as Controls
import QtQuick.Layouts

Rectangle {
	id: root

	color: "black"
	anchors.fill: parent

	property real maxTankLabelWidth: 0

	Item {

		TankLevelRepeater {
			width: 400
			model: [{
					text: "Gas",
					level: 0.5,
					icon:""
				}, {
					text: "Gas 2",
					level: 0.8,
					icon:""
				}, {
					text: "Grey Waste",
					level: 0.7,
					icon:""
				}]
		}

		anchors {
			fill: parent
			leftMargin: 5
			topMargin: 5
		}
	}

	component TankLevelRepeater: ColumnLayout {
		id: ctl

		spacing: 8

		property color labelColor: "white"
		property color valueColor: "#2196F3"
		property color levelColor: "#332196F3"

		property real level: 0.5
		property real levelThickness: 6
		property real _maxTextWidth: 0
		property alias model: repeater.model

		Repeater {
			id: repeater

			RowLayout {
				id: row
				Layout.fillWidth: true
				spacing: 6

				Item {

					Layout.preferredWidth: ctl._maxTextWidth
					Layout.preferredHeight: labelText.implicitHeight
					Layout.alignment: Qt.AlignVCenter

					Text {
						id: labelText
						text: modelData.text
						color: ctl.labelColor
						anchors.right: parent.right
						anchors.verticalCenter: parent.verticalCenter

						// Pure measurement signal: updates maxTextWidth safely without clipping feedback
						onImplicitWidthChanged: {
							if (implicitWidth > ctl._maxTextWidth) {
								ctl._maxTextWidth = implicitWidth;
							}
						}
					}

				}

				Image {
					source: modelData.icon
					Layout.fillHeight: true

				}

				Rectangle {
					id: levelRectangleBack
					implicitHeight: ctl.levelThickness
					color: ctl.levelColor
					radius: height / 2
					Layout.fillWidth: true
					Layout.alignment: Qt.AlignVCenter

					Rectangle {
						anchors.top: parent.top
						anchors.bottom: parent.bottom
						width: parent.width * Math.max(0, Math.min(1, modelData.level))
						color: ctl.valueColor
						radius: levelRectangleBack.radius
					}
				}
			}
		}
	}


}
