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
import Vespera 1.0

OverviewPage {
	id: root

	property string bindPrefix
	property string settingsPrefix

	Text {
		text: "No device found"
		visible: !root.bindPrefix
		anchors.centerIn: parent
	}

	Component.onCompleted: addServices()

	function addServices() {
		var devices = VesperaDeviceModel.deviceList
		for (var i = 0; i < devices.rowCount; i++)
			if (__addService(devices, i) === false) return
	}

	function removeServices() {
		var devices = VesperaDeviceModel.deviceList
		for (var i = 0; i < devices.rowCount; i++)
			if (__removeService(devices, i) === false) return
	}

	function __addService(devices, idx) {
		var currentIndex = devices.index(idx, 0)
		var uid = devices.data(currentIndex, VeQItemTableModel.UniqueIdRole)
		return onAddService(uid)
	}

	function __removeService(devices, idx) {
		var currentIndex = devices.index(idx, 0)
		var uid = devices.data(currentIndex, VeQItemTableModel.UniqueIdRole)
		return onRemoveService(uid)
	}

	Connections {
		target: VesperaDeviceModel.deviceList

		function onRowsInserted(parent, first, last) {
			for (var i = first; i <= last; i++)
				if (root.__addService(target, i) === false) return
		}

		function onRowsAboutToBeRemoved(parent, first, last) {
			for (var i = first; i <= last; i++)
				if (root.__removeService(target, i) === false) return
		}

	}
}