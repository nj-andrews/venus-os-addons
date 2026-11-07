import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
	id: root

	background: Rectangle {
		color: "grey"
	}
	anchors.fill: parent

	RowLayout {
		id: mainRow
		spacing: 1
		anchors {
			left: parent.left
			right: parent.right
		}

		RoomTempsColumnLayout {
		}
		TankLevelsColumnLayout {
			model: tankModel
			Layout.fillWidth: true
			Layout.fillHeight: true
			Layout.preferredWidth:0
		}

		InputLoadsColumnLayout {
		}
		BatteryInfoColumnLayout {
			Layout.fillWidth: true
			Layout.preferredWidth:0
		}
		OutputLoadsColumnLayout {
		}
	}

	component RoomTempsColumnLayout: ColumnLayout {
		spacing: 1
		Rectangle {
			color: "red"
			Layout.preferredWidth: 100
			Layout.preferredHeight: 100
		}
		Rectangle {
			color: "green"
			Layout.preferredWidth: 40
			Layout.preferredHeight: 40
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
		color: "red"

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
				Layout.fillHeight: true
			}
		}
	}

	component BatteryInfoColumnLayout: ColumnLayout {
		Rectangle {
			id: battery
			border.color: "yellow"
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
				Layout.fillHeight: true
			}
		}
	}

	component Label: Text {
		color: "white"
	}
	property string dummySvg: "data:image/svg+xml;utf8," + "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>" + "<circle cx='12' cy='12' r='11' fill='#3498db' stroke='#FF0000' stroke-width='2'/>" + "</svg>"
}
