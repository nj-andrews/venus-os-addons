import QtQuick 2
import Victron.VenusOS

Page {
	id: page
	title: qsTr("Open Package Manager")

	Component.onDestruction: vespera?.cleanup()
	Component.onCompleted: {
		console.log("HELLO WORLD:InetboxPageSettings")
	}

	GradientListView {
		id: settingsListView

		model: VisibleItemModel {

			ListSwitch {
				dataItem.uid:!!Global.systemSettings ? Global.systemSettings.serviceUid + "/Settings/Inetbox/ShowMotorhomePage" : ""
				text: "Show Motorhome Page"
			}

			ListLink {
				id: documentation

				//% "Documentation"
				text: qsTrId("pagecontrollableloads_documentation")
				url: "https://nj-andrews.github.io/venus-os-addons/"
			}
		}
	}

	function findPageIndex(url) {
		var navPages = Global.pageManager.navBar.pages
		for (var i = 0; i < navPages.count; i++) {
			if (navPages[i].uri == url)
				return i
		}
		return -1
	}
	function addRemovePage(add) {
		var url = "qrc:/Inetbox/MotorhomePage.qml"
		var idx = findPageIndex(url)
		if (idx == -1) {
			var page = createPage(url)
			Global.pageManager.navBar.pages.push(page)

		}
		Global.pageManager.navBar.pages.pop(idx)

	}

	function createPage(url) {

		var component = Qt.createComponent(url);

		if (component.status === Component.Ready) {
				// 2. Instantiate the object.
				// Pass 'parentItem' so it is visible in the UI hierarchy, or 'root' for context.
				var page = component.createObject(Global.pageManager.navBar,
							{view:Global.mainView.swipeView});

				if (motorhomeObject === null) {
						console.error("Error instantiating the Motorhome object");
				} else {
						console.log("Successfully created:", page);
						return page
				}
		} else if (component.status === Component.Error) {
				console.error("Error loading component:", component.errorString());
		}
	}

}
