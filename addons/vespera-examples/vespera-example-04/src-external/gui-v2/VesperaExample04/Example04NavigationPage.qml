import QtQuick
import Victron.VenusOS

SwipeViewPage {
	url: "qrc:/VesperaExample04/Example04NavigationPage.qml"
	iconSource: "qrc:/VesperaExample04/images/button_icon.svg"
	//% "Example 4"
	title: qsTrId("vespera_example4_title")

	GradientListView {
		model: VisibleItemModel {
			ListText {
				//% "This page was registered using installer-navigation-page"
				text: qsTrId("vespera_example4_registered_message")
			}
		}
	}
}
