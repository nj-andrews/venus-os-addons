import QtQuick
import QtQuick.Layouts
import Victron.VenusOS

Rectangle {
	id: root

	color: Theme.color_background_secondary
	radius: Theme.geometry_button_radius
	implicitHeight: powerRow.implicitHeight + powerRow.anchors.margins * 2

	property bool animationEnabled
	property bool allSourcesVisible: dcInputLoads.visible && dcInGaugeQuantity.visible && acInGaugeQuantity.visible
	property real gaugeFontScaleFactor: Theme.screenSize !== Theme.Portrait
					? (root.allSourcesVisible ? 0.8 : 1.0)
					: 1.0

	RowLayout {
		id: powerRow
		anchors.fill: parent
		anchors.margins: Theme.screenSize === Theme.Portrait ? 2 : 8
		// Input loads
		ColumnLayout {
			id: dcInputLoads
			spacing: 1

			MotorhomeGaugeQuantityRow {
				id: solarYield
				visible: Global.solarInputs.inputCount > 0
				alignment: Qt.AlignLeft | Qt.AlignTop
				fontScaleFactor: root.gaugeFontScaleFactor
				icon.source: "qrc:/images/solaryield.svg"
				quantityLabel.sourceType: VenusOS.ElectricalQuantity_Source_Any
				quantityLabel.dataObject: Global.system.solar
			}

			MotorhomeGaugeQuantityRow {
				id: dcInGaugeQuantity
				visible: Global.dcInputs.model.count > 0
				alignment: Qt.AlignLeft | Qt.AlignBottom
				fontScaleFactor: root.gaugeFontScaleFactor
				icon.source: Global.dcInputs.model.count === 1 ? VenusOS.dcMeter_iconForType(Global.dcInputs.model.firstMeterType) : VenusOS.dcMeter_iconForMultipleTypes()
				quantityLabel.sourceType: VenusOS.ElectricalQuantity_Source_Dc
				quantityLabel.dataObject: Global.dcInputs
			}

			MotorhomeGaugeQuantityRow {
				id: acInGaugeQuantity
				visible: Global.acInputs.findValidSource() !== VenusOS.AcInputs_InputSource_NotAvailable
				alignment: Qt.AlignLeft | Qt.AlignVCenter
				fontScaleFactor: root.gaugeFontScaleFactor
				icon.source: Global.acInputs.sourceIcon(Global.acInputs.highlightedInput?.source ?? Global.acInputs.findValidSource())
				quantityLabel.sourceType: VenusOS.ElectricalQuantity_Source_AcInputOnly
				quantityLabel.dataObject: Global.acInputs.highlightedInput
			}
		}

		// Battery
		ColumnLayout {
			MotorhomeBattery {
				id: batteryWidget
				animationEnabled: root.animationEnabled
				size: VenusOS.OverviewWidget_Size_L
				topPadding: 0
				Layout.fillWidth: true
			}
		}

		// Output loads
		ColumnLayout {
			id: outputLoads
			spacing: 1

			MotorhomeGaugeQuantityRow {
				id: acLoadGauge
				visible: Global.system.hasAcLoads
				alignment: Qt.AlignRight | Qt.AlignVCenter
				fontScaleFactor: root.gaugeFontScaleFactor
				icon.source: "qrc:/images/acloads.svg"
				quantityLabel.sourceType: VenusOS.ElectricalQuantity_Source_Ac
				quantityLabel.dataObject: Global.system.load.ac
			}

			MotorhomeGaugeQuantityRow {
				id: dcLoadGauge
				visible: Global.system.dc.hasPower
				alignment: Qt.AlignRight | Qt.AlignVCenter
				fontScaleFactor: root.gaugeFontScaleFactor
				icon.source: "qrc:/images/dcloads.svg"
				quantityLabel.sourceType: VenusOS.ElectricalQuantity_Source_Dc
				quantityLabel.dataObject: Global.system.dc
			}
		}
	}
}
