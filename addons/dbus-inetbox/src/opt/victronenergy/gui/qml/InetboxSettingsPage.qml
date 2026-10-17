import QtQuick 2
import com.victron.velib 1.0
import "utils.js" as Utils

MbPage {
	id: root

	model: VisibleItemModel {
		MbSwitch {
			bind: "com.victronenergy.settings/Settings/Vespera/CustomOverviewPages/InetboxOverview"
			name: qsTr("Show Overview page")
			valueFalse: ""
			valueTrue: "^"
		}

	}
}
