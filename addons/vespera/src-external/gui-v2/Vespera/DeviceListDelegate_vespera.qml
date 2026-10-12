import QtQuick
import Victron.VenusOS
import "qrc:/Vespera/components/VesperaSingleton.js" as VesperaSingleton

DeviceListDelegate {
	id: root
	height: 0

	onDeviceChanged: {
		var isReload = VesperaSingleton.getIsReload()

		console.debug("Vespera: DeviceListDelegate::onDeviceChanged: isRelead=", isReload)

		// Using callLater fixes intermitten lock ups
		Qt.callLater(function () {
			parent.height=0
			parent.active = false
		})

		if (isReload) {
			Global.mainView.swipeView.animationEnabled = false
			Global.mainView.navBar.setCurrentIndex(-1)
		}

		if (!VesperaSingleton.customPageModelExists()) {
			VesperaSingleton.createCustomPageModel(Global.main)
		} else {
			console.debug("Vespera: Singleton exists")
		}

		if (isReload) {
			VesperaSingleton.setIsReload(false)

			Global.pageManager.popAllPages(1)

			Qt.callLater(function () {
				Global.mainView.navBar.setCurrentIndex(0)
				Global.mainView.swipeView.animationEnabled = true
			})

		}

	}
	// Component.onDestruction: {
	// 	console.debug("Vespera device delegate:DESTROYED")
	// }

}
