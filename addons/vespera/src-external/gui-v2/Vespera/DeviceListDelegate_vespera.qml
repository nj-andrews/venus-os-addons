import QtQuick
import Victron.VenusOS
import "qrc:/Vespera/components/VesperaSingleton.js" as VesperaSingleton

DeviceListDelegate {
	id: root
	height: 0

	onDeviceChanged: {

		// Using callLater fixes intermitten lock ups
		Qt.callLater(function () {
			var isReload = VesperaSingleton.getIsReload()

			parent.height=0
			parent.active = false

			if (isReload) {
				Global.mainView.swipeView.animationEnabled = false
				Global.mainView.navBar.setCurrentIndex(-1)
			}

			VesperaSingleton.initCustomPageModel(Global.main, isReload)

			if (isReload) {
				// sometimes the UI renders a blank page on startup
				// using callLater fixes this
				Qt.callLater(function () {
					// accessing any property of the page fixes the issue.
					Global.pageManager.popAllPages(StackView.Immediate)
					Global.mainView.navBar.setCurrentIndex(0)
					Global.mainView.swipeView.animationEnabled = true
				})
			}
		})
	}
	// Component.onDestruction: {
	// 	console.debug("Vespera device delegate:DESTROYED")
	// }

}
