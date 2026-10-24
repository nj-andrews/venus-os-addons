import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.impl as CP
import Victron.VenusOS

Rectangle {
	id: tanks

	implicitHeight: col.implicitHeight + col.anchors.margins * 2
	color: Theme.color_background_secondary
	radius: Theme.geometry_button_radius

	property alias model: repeater.model
	property real levelThickness: 6

ColumnLayout {
	id: col
	spacing: 1
	anchors.fill: parent
	anchors.margins: 8

	Repeater {
		id: repeater

		property real maxLabelWidth: 0

		Loader {
			id: tankLoader
			// 1. Only instantiate the component if it's not a battery
			active: model.tankType !== VenusOS.Tank_Type_Battery
			visible: active

			Layout.fillHeight: true
			Layout.fillWidth: true

			sourceComponent: Row {
				id: row
				width: tankLoader.width
				height: tankLoader.height
				spacing: 6

				property int gaugeStatus: Theme.getValueStatus(model.level, model.valueType)
				property color valueColor: Theme.statusColorValue(row.gaugeStatus)
				property color levelColor: Theme.statusColorValue(row.gaugeStatus, true)

				// 1. [name] Right-aligned, sized dynamically to the longest string
				Label {
					id: valueLabel
					text: model.name
					horizontalAlignment: Text.AlignRight
					anchors.verticalCenter: parent.verticalCenter
					font.pixelSize: Theme.font_size_body2
					property int unit
					property quantityInfo quantity

					states: State {
						when: Global.systemSettings.briefView.unit.value !== VenusOS.BriefView_Unit_None
						PropertyChanges {
							target: valueLabel
							text: model.name + " " + quantity.number + quantity.unit
							quantity: Units.getDisplayText(unit, value)
							unit: Global.systemSettings.briefView.unit.value === VenusOS.BriefView_Unit_Percentage
									? VenusOS.Units_Percentage : Global.systemSettings.volumeUnit
						}
					}

					onImplicitWidthChanged: {
						if (implicitWidth > repeater.maxLabelWidth)
							repeater.maxLabelWidth = implicitWidth;
					}
					width: repeater.maxLabelWidth
				}

				// 2. [Icon]
				CP.IconImage {
					id: img
					source: model.icon
					width: Theme.geometry_widgetHeader_icon_size
					fillMode: Image.Pad
					anchors.verticalCenter: parent.verticalCenter
					color: Theme.color_font_primary
				}

				// Background fill
				Rectangle {
					id: levelBack
					anchors.verticalCenter: parent.verticalCenter
					width: Math.max(50, row.width - valueLabel.width - img.width - row.spacing*2)
					height: levelThickness
					color: row.levelColor
					radius: height / 2
					Rectangle {
						anchors.left: parent.left
						height: parent.height
						width: levelBack.width * model.level / 100
						color: row.valueColor
						radius: height / 2
					}
				}
			}
		}
	}
}
}