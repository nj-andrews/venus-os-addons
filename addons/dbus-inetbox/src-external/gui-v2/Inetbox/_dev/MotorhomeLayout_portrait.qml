import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
	id: root

	background: Rectangle {
		color: "grey"
	}
	anchors.fill: parent

	ColumnLayout {
		id: mainRow
		spacing: 10
		anchors {
			margins: 10
			top: parent.top
			left: parent.left
			right: parent.right
		}

		TankLevelsColumnLayout {
			model: tankModel
			Layout.fillWidth: true
			//Layout.preferredWidth:0
		}

		// Power
		RowLayout {

			InputLoadsColumnLayout {
			}
			BatteryInfoColumnLayout {
			}
			OutputLoadsColumnLayout {
			}
		}
		Rectangle {
			Layout.fillWidth: true
			implicitHeight: inetboxColumn.implicitHeight
			color: "dimgrey"
			radius: 12
			ColumnLayout {
				id: inetboxColumn
				anchors.fill: parent

				// Room Temps
				Layout.alignment: Qt.AlignTop
				RowLayout {
					id: mainTemps
					spacing: 10

					QuantityLabel {
						id: tempValue
						font.pixelSize: 36
						Layout.alignment: Qt.AlignBottom
						text: "17"
					}

					QuantityLabel {
						font.pixelSize: 18
						Layout.alignment: Qt.AlignBottom

						text: "22"
					}

					// IC.MinimalSlider {
					// 	id: targetTemperatureSlider
					// 	hideTicks: false
					// 	visible: inetbox.heatingOn || inetbox.airconOn
					// 	value: inetbox.targetTemperature

					// 	Layout.alignment: Qt.AlignBottom
					// 	Layout.fillWidth: true

					// 	onPressedChanged: {
					// 		if (!pressed) // only update when button is released
					// 			inetbox.updateTargetTemperature();
					// 	}
					// 	from: inetbox.heatingOn ? 5 : 16
					// 	to: inetbox.heatingOn ? 30 : 31
					// 	stepSize: 1
					// }
				}
			}
		}
	}

	component RoomTempsRowLayout: RowLayout {

		Label {
			id: temp1
			font.pixelSize: 44
			text: "22c"

			Layout.alignment: Qt.AlignBaseline
		}
		Label {
			id: temp2
			font.pixelSize: 26
			text: "22c"

			Layout.alignment: Qt.AlignBaseline
		}
	}

	property var tankModel: [{
			"color": "green",
			"name": "Battery",
			"tankType": 2,
			"icon": dummySvg,
			"level": 0.5
		}, {
			"color": "green",
			"name": "Gas",
			"tankType": 1,
			"icon": dummySvg,
			"level": 0.5
		}, {
			"color": "green",
			"name": "Frest water",
			"tankType": 1,
			"icon": dummySvg,
			"level": 0.8
		}, {
			"color": "green",
			"name": "Grey Waste",
			"tankType": 1,
			"icon": dummySvg,
			"level": 0.2
		},]

	component TankLevelsColumnLayout: Rectangle {
		id: tanks

		implicitHeight: col.implicitHeight + 8
		radius: 12
		color: "dimgrey"

		property alias model: repeater.model
		property real levelThickness: 6
		property real maxLabelWidth: 0
		ColumnLayout {
			id: col

			spacing: 1
			anchors.fill: parent
			anchors.margins: 4
			Repeater {
				id: repeater

				Loader {
					id: tankLoader

					// 1. Only instantiate the component if it's not a battery
					active: true// .tankType !== 2 //VenusOS.Tank_Type_Battery
					visible: active

					Layout.fillWidth: true

					sourceComponent: Row {
						id: row
						width: tankLoader.width
						height: tankLoader.height
						spacing: 6

						property color valueColor: "steelblue"
						property color levelColor: "lightblue"

						Label {
							id: valueLabel
							text: modelData.name
							horizontalAlignment: Text.AlignRight
							anchors.verticalCenter: parent.verticalCenter

							onImplicitWidthChanged: {
								if (implicitWidth > tanks.maxLabelWidth)
									tanks.maxLabelWidth = implicitWidth;
							}
							width: tanks.maxLabelWidth
						}

						// 2. [Icon]
						Image {
							id: img
							source: modelData.icon
							anchors.verticalCenter: parent.verticalCenter
							fillMode: Image.PreserveAspectFit
						}

						// Background fill
						Rectangle {
							id: levelBack
							anchors.verticalCenter: parent.verticalCenter

							width: Math.max(10, row.width - valueLabel.width - img.width - row.spacing * 2)
							height: tanks.levelThickness
							color: row.levelColor
							radius: height / 2
							Rectangle {

								anchors.left: parent.left
								height: parent.height
								width: levelBack.width * modelData.level
								color: row.valueColor
								radius: height / 2
							}
						}
					}
				}
			}
		}
	}

	property string info

	Label {
		anchors {
			top: mainRow.bottom
		}
		text: "info:" + info
	}
	component InputLoadsColumnLayout: ColumnLayout {
		id: inputLoad
		width: 100
		spacing: 1

		Repeater {
			model: ["red", "white", "blue"]

			Rectangle {
				color: modelData
				width: parent.width
				height: 50
			}
		}
	}

	component BatteryInfoColumnLayout: ColumnLayout {
		Rectangle {
			color: "steelblue"
			Layout.fillWidth: true
			Layout.fillHeight: true
		}
	}

	component OutputLoadsColumnLayout: ColumnLayout {
		id: outputLoad
		width: 100

		spacing: 1

		Repeater {
			model: ["red", "white", "blue"]

			Rectangle {
				color: modelData
				width: parent.width
				height: 50
			}
		}
	}

	component Label: Text {
		color: "white"
	}

	component QuantityLabel: Item {
		property alias text: lbl.text
		property alias font: lbl.font
		implicitWidth: lbl.width
		implicitHeight: lbl.height
		Text {
			id: lbl
		}
	}

	property string dummySvg: "data:image/svg+xml;utf8," + "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>" + "<circle cx='12' cy='12' r='11' fill='#3498db' stroke='#FF0000' stroke-width='2'/>" + "</svg>"
}
