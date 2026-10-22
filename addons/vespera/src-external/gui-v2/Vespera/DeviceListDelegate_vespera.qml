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
				Global.pageManager.popAllPages(StackView.Immediate)
				// sometimes IOS renders a blank page on startup
				// accessing any property of the page fixes the issue.
				var _ = Global.mainView.navBar.pages[0].url

				Global.mainView.navBar.setCurrentIndex(0)
				Global.mainView.swipeView.animationEnabled = true
			}
		})
	}
	// Component.onDestruction: {
	// 	console.debug("Vespera device delegate:DESTROYED")
	// }

}
