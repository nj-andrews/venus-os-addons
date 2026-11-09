import QtQuick
import Victron.VenusOS

Page {
	title: "Vespera Example 3 plugin"

	GradientListView {
		model: VisibleItemModel {
			ListText {
				text: "Hello world from the Vespera Example 3 plugin"
			}
		}
	}
}
