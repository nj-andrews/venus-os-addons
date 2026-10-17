/*
VesperaCustomOverviewPage.qml
Base class for a custom OverviewPage.
Used in conjunction with the VesperaCustomOverviewPages.qml code.
Derived class can add the optional functions beloww for handling of
multiple services of the same type:
function onAddService(uid) {}
function onRemoveService(uid) {}
					if onRemoveService is implemented it must call
					extraOverview(pageName, false) when removing the page
	return true to stop processing of other services of the same type
	if multiple services of the same type is not supported.

Derived qml page must set:
  source: [page name]
example:
  source: "InetboxOverview.qml"
*/

import QtQuick 2

OverviewPage {
	id: root

	readonly property string bindPrefix: service?.value ?? ""
	property string settingsPrefix
	required property string source

	VBusItem { id:service; bind: settingsPrefix + "/ServiceName"}

	Component.onCompleted: {
		addServices()
	}

	function addServices() {
		//see Main.qml for vesperaCustomOverviewPages
		for (var i = 0; i < vesperaCustomOverviewPages.pages.rowCount; i++) {
			let [uid, pageName] = vesperaCustomOverviewPages.getPageInfo(i)
			if (addService(uid, pageName))
				return
		}
	}

	function addService(uid, pageName) {
		if (pageName === source) {
			settingsPrefix = uid
			// check for and call override if available
			if (typeof onAddService === "function")
					return onAddService(uid)

			return true // we only support 1 service for now.
		}
	}

	function removeService(uid, pageName) {
		if (pageName === source) {
			// check for and call override if available
			if (typeof onRemoveService === "function")
					return onRemoveService(uid)

			if (root.bindPrefix === uid) {
				extraOverview(pageName, false)
				return true
			}
		}
	}

	Connections {
		target: vesperaCustomOverviewPages.pages

		function onRowsInserted(parent, first, last) {
			for (var i = first; i <= last; i++) {
				let [uid, pageName] = vesperaCustomOverviewPages.getPageInfo(i)
				if (addService(uid, pageName))
					return
			}
		}

		function onRowsAboutToBeRemoved(parent, first, last) {
			for (var i = first; i <= last; i++) {
				let [uid, pageName] = vesperaCustomOverviewPages.getPageInfo(i)
				if (removeService(uid, pageName))
					return
			}
		}
	}

}
