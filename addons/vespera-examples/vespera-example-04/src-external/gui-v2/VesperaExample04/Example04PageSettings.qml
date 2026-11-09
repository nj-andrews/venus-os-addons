import QtQuick
import Victron.VenusOS

Page {

	//% "Vespera Example 4 plugin"
	title: qsTrId("vespera_example4_title")

	GradientListView {
		model: VisibleItemModel {
			ListText {
				//% "Hello world from the Vespera Example 3 plugin"
				text: qsTrId("vespera_example4_hello_world")
			}
		}
	}
}
