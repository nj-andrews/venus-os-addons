import QtQuick
import QtQuick.Controls.impl as CP
import Victron.VenusOS

Row {
	id: root

	property int alignment: Qt.AlignTop | Qt.AlignLeft
	property alias icon: icon
	property alias quantityLabel: quantityLabel
	property real fontScaleFactor: 1.0

	spacing: Theme.geometry_briefPage_edgeGauge_quantityLabel_spacing
	layoutDirection: root.alignment & Qt.AlignRight ? Qt.RightToLeft : Qt.LeftToRight

	CP.ColorImage {
		id: icon
		anchors.verticalCenter: parent.verticalCenter
		fillMode: Image.Pad
		color: Theme.color_font_primary
	}

	ElectricalQuantityLabel {
		id: quantityLabel
		anchors.verticalCenter: parent.verticalCenter
		font.pixelSize: Theme.font_briefPage_quantityLabel_size * root.fontScaleFactor
	}
}
