import QtQuick 2
import Vespera 1.0
import "vespera-utils.js" as VesperaUtils

QtObject {

	readonly property VeQItemSortTableModel pages:
		VeQItemSortTableModel {
			dynamicSortFilter: true
			filterFlags: VeQItemSortTableModel.FilterInvalid
			model: VeQItemChildModel {
				id:child
				model: VesperaDeviceModel.deviceList
				childId: "OverviewPage"
			}

			onRowsInserted: function(p, first, last) {onPagesInserted(first, last)}
		}

	function onPagesInserted(first, last) {
		console.log(`onRowsInserted: ${first}, ${last}`)
		for (var i = first; i <= last; i++) {
			let [uid, pageName] = getPageInfo(i)
			if (pageName)
				extraOverview(pageName, true)
		}
	}

	Component.onCompleted: {
		if (pages.rowCount>0) onPagesInserted(0, pages.rowCount)
	}

	function getPageInfo(index) {
		var currentIndex = pages.index(index, 0)
		var pageName = pages.data(currentIndex, VeQItemTableModel.ValueRole)

		if (pageName) {
			var uid = pages.data(currentIndex, VeQItemTableModel.UniqueIdRole)
			uid = uid.substring(0,uid.length - child.childId.length - 1)
			if (!pageName.endsWith(".qml")) pageName += ".qml"
			return [uid, pageName]
		}
		return ["", ""]
	}

	property VeQuickItem customMenuItems: VeQuickItem {
		uid: "dbus/com.victronenergy.settings/Settings/Vespera/CustomMenuPages"
		onValueChanged: VesperaUtils.initCreateComponent(customMenuItems)
	}

  property VeQuickItem customPages: VeQuickItem {
		uid: "dbus/com.victronenergy.settings/Settings/Vespera/CustomOverviewPages"
		onValueChanged: {
			VesperaUtils.addRemoveCustomItemsQuick(
			customPages, overviewModel, createComponentFactory, getPageIndex)
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