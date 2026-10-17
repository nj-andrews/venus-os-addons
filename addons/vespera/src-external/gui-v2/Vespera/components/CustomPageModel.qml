import QtQuick 2
import Victron.VenusOS
import "qrc:/Vespera/components/VesperaSingleton.js" as VesperaSingleton

QtObject {
	id: root

	Component.onCompleted: {
		if (allPagesLoaded)
			root.syncPages()
	}

	property bool allPagesLoaded: Global.mainView != undefined
															&& Global.mainView.swipeView != undefined
															&& Global.mainView.swipeView.ready

	property bool _inSyncPages: false
	property var _customPages: []
	property var _customPageItems : ({})

	property VeQuickItem _customPagesItem: VeQuickItem {
		uid: !!Global.systemSettings ? Global.systemSettings.serviceUid + "/Settings/Vespera/CustomNavPages" : ""
		onValueChanged: root.onCustomPagesChanged(value)
	}

	property Connections connections: Connections {
		target: Global.mainView?.swipeView?.contentModel ?? null

		function onModelUpdated() {
			if (root._inSyncPages)
				return
			//Coalesces multiple calls
			Qt.callLater(function () { root.syncPages() })
		}
	}

	function onCustomPagesChanged(value) {

		if (!_customPagesItem.valid)
			return
		if (!value)
			value = ""

		console.debug("CustomPageModel: onCustomPagesChanged:", "pages=", value)

		var customPagesArray = []
		if (value) {
			var parts = value.split(",")
			for (var i = 0; i < parts.length; ++i) {
				var item = parts[i].trim()
				if (item) customPagesArray.push(item)
			}
		}

		if (allPagesLoaded == false) {
			_customPages = customPagesArray
			return
		}

		root.syncPages(customPagesArray)
	}

	function toggleCustomPage(pageName, checked) {
		console.log("CustomPageModel: toggleCustomPage: in:", pageName, checked)
		var customPages = _customPages.slice()
		var removed = false
		for (var i = 0; i< customPages.length; i++) {
			var itemName = customPages[i]
			if (pageName = itemName) {
				if (checked) {
					console.log("CustomPageModel: toggleCustomPage: exit already checked")
					return // already exists
				}
				removed = true
				customPages.splice(i, 1);
			}
		}

		if (checked)
			customPages.push(pageName)
		else if (!removed) {
			console.log("CustomPageModel: toggleCustomPage: exit already unchecked")
			return // already exists
		}

		console.log("CustomPageModel: setting value")
		var pages = customPages.join(", ")
		_customPagesItem.setValue(pages)

	}

	function syncPages(customPages) {
		console.debug("CustomPageModel: syncPages in:", root._inSyncPages)
		if (root._inSyncPages || !Global.mainView.swipeView) {
			console.debug("CustomPageModel: out")
			return
		}


		_inSyncPages = true

		if (customPages === undefined)
			customPages = _customPages;

		const model = Global.mainView.swipeView.contentModel

		//
		// Build current page lookup from the SwipeView model
		//
		const currentPages = {}

		for (let i = 0; i < model.count; ++i) {
			const page = model.get(i)
			if (page.url)
				currentPages[page.url] = page
		}

		//
		// Build requested page lookup
		//
		const requestedPages = {}

		for (var url of customPages)
			requestedPages[url] = true

		//
		// Remove custom pages that no longer exist
		//
		for (var url of _customPages) {
			if (requestedPages[url])
				continue

			const page = _customPageItems[url]
			if (removePage(page))
				delete _customPageItems[url]
		}

		//
		// Add new custom pages.
		// Insert backwards so final order matches customPages.
		//
		//console.debug("CustomPageModel: syncPages customPages:", customPages.length )
		for (var i = customPages.length - 1; i >= 0; --i) {
			const url = customPages[i]

			if (currentPages[url])
				continue // page already exists

			var page = _customPageItems[url]
			if (!page) {
				page = VesperaSingleton.createPage(url, Global.mainView, {view:Global.mainView.swipeView})
				if (!page) continue
				_customPageItems[url] = page
			}
			//console.debug("CustomPageModel: syncPages insertItem:", page )
			Global.mainView.swipeView.insertItem(0, page)
		}

		//
		// Update NavBar pages from the final SwipeView model
		//

		Global.mainView.navBar.pages.length = model.count
		for (var i = 0; i < model.count; ++i)
			Global.mainView.navBar.pages[i] = model.get(i)

		_customPages = customPages
		_inSyncPages = false
	}

	function removePage(page) {
		const swipeView = Global.mainView.swipeView

		for (let i = 0; i < swipeView.contentChildren.length; ++i) {
			if (swipeView.contentChildren[i] === page) {
				swipeView.removeItem(page)
				return true
			}
		}

		return false
	}

	onAllPagesLoadedChanged: {

		VesperaSingleton.setIsReload(true)
		if (allPagesLoaded == false) {
			var hadCustomPages = _customPageItems.length>0
			_customPageItems = ({})
			if (hadCustomPages)
				VesperaSingleton.clearCache()
			return;
		}

		if (root._inSyncPages)
			return
		//Coalesces multiple calls
		Qt.callLater(function () { root.syncPages() })
	}

}
