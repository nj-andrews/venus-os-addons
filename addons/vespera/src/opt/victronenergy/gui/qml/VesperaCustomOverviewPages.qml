import QtQuick 2
import Vespera 1.0
import "vespera-utils.js" as VesperaUtils

QtObject {

	Component.onCompleted: {
		VesperaUtils.addRemoveCustomItems(
				customPagesItem, overviewModel, createComponentFactory, getPageIndex)
	}

  property VeQuickItem customPagesItem: VeQuickItem {
		uid: "dbus/com.victronenergy.settings/Settings/Vespera/CustomOverviewPages"
		onValueChanged: {
			VesperaUtils.addRemoveCustomItems(
				customPagesItem, overviewModel, createComponentFactory, getPageIndex)
		}
	}

	function createComponentFactory(pageFileName, model, action, index) {

		if (action === "-") {
			model.remove(index)
		} else if (!VesperaUtils.qmlFileExists(pageFileName)) {
			console.log("Skipping missing custom overview page: " + pageFileName)
		} else if (action === "*") { // replace
			model.setProperty(index, "pageSource", pageFileName)
		} else {
			model.append({"pageSource": pageFileName})
			if (index != -2) {
				// Then move all the pages behind index
				model.move(index, model.count - 2, model.count - 2)
			}
		}

		return undefined

	}

	function getPageIndex(model, page) {
		for (var i = 0; i < model.count; i++)
			if (model.get(i).pageSource === page)
				return i
		return -1
	}

}