import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T
import QtQuick.Controls.impl as CP
import Victron.VenusOS
import Victron.Gauges
import "./components" as IC

Page {
	id: root

	required property var inetboxModel
	required property bool animationEnabled
	required property GaugeModel gaugeModel
	readonly property real buttonOffsetX: 0

	ColumnLayout {
		id: mainRow
		spacing: 10
		anchors {
			left: parent.left
			right: parent.right
			leftMargin: Theme.geometry_page_content_horizontalMargin
			rightMargin: Theme.geometry_page_content_horizontalMargin
		}

		IC.MotorhomeTankLevels {
			model: root.gaugeModel
			Layout.fillWidth: true
		}

		// Power
		IC.MotorhomePower {
			Layout.fillWidth: true
			animationEnabled: root.animationEnabled
		}
		IC.MotorhomeInetbox {
			model: root.inetboxModel
			Layout.fillWidth: true
		}

		Rectangle {
			Layout.fillWidth: true
			visible: root.inetboxModel.device
			color: Theme.color_background_secondary
			radius: Theme.geometry_button_radius
			Layout.preferredHeight: auxButtons.implicitHeight + Theme.geometry_page_content_verticalMargin
			IC.InetboxAuxButtons {
				id: auxButtons
				inetboxModel: root.inetboxModel
				anchors {
					left: parent.left
					leftMargin: Theme.geometry_page_content_horizontalMargin
					verticalCenter: parent.verticalCenter
				}
			}
		}
	}
}