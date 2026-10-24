import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.impl as CP
import Victron.VenusOS
import Victron.Gauges
import "./components" as IC

Page {
	id: root

	required property var inetboxModel
	required property bool animationEnabled
	required property GaugeModel gaugeModel

	property string image_boat_glow: "qrc:/images/boat_glow.png"

	// Tank Levels
	RowLayout {
		id: mainRow
		spacing: 20

		anchors {
			left: parent.left
			leftMargin: Theme.geometry_page_content_horizontalMargin
			rightMargin: Theme.geometry_page_content_horizontalMargin
			right: parent.right
		}
		IC.MotorhomeTankLevels {
			model: root.gaugeModel
			Layout.fillWidth: false
			Layout.fillHeight: true
      Layout.preferredWidth: mainRow.width * 0.42
		}
		IC.MotorhomePower {
			Layout.fillWidth: true
			animationEnabled: root.animationEnabled
		}
	}

	// Component {
	// 	id: scheduleDialog
	// 	InetboxHeatingScheduleDialog {
	// 		key:"Heating"
	// 		inetboxModel: root.inetboxModel
	// 		// scheduleEnabled: true,
	// 		// scheduleTemp: 0,
	// 		// scheduleMode: "Boost"
	// 	}
	// }

	IC.InetboxAuxButtons {
		inetboxModel: root.inetboxModel
		buttonOffset: 30
		anchors {
			top: bg_image2.top; topMargin: 40
			right: bg_image2.right; rightMargin: 180
		}
	}

	ColumnLayout {
		anchors {
			left: parent.left; leftMargin: 40
			top: mainRow.bottom; topMargin: 5
			right: bg_image.right
			bottom: bg_image.bottom; bottomMargin:40
		}

		IC.MotorhomeInetbox {
			model: root.inetboxModel
			color: "transparent"
			targetTemperatureSlider.hideTicks: Theme.screenSize !== Theme.Portrait
			buttonOffsetX: 20
			Layout.fillHeight: true
			Layout.fillWidth: true
			Layout.leftMargin: 60
		}
	}

	// version
	Label {
		color: Theme.color_gray4
		font.pixelSize: Theme.font_size_caption
		anchors {
			right: parent.right
			rightMargin: 70
			bottom: bg_image.bottom
		}
		text: root.inetboxModel.version
	}

	// left image
	CP.ColorImage {
		id: bg_image
		height: 370
		mirror: true
		rotation: 180
		source:root.image_boat_glow
		width: 800
		z: -1
		anchors {
			left: parent.left
			leftMargin: 20
			top: mainRow.top
			topMargin: 100
		}
	}

	//right image
	CP.ColorImage {
		id: bg_image2
		height: 370
		mirror: true
		//rotation: 180
		source: root.image_boat_glow
		width: 800
		z: -1
		anchors {
			right: parent.right
			leftMargin: 20
			top: mainRow.top
			topMargin: 185
		}
	}
}
