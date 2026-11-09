import QtQuick 2

VesperaCustomOverviewPage {
	id: root

	function onAddService(uid) {
		root.bindPrefix = uid
		return true
	}

	function onRemoveService(uid) {
		if (root.bindPrefix === uid) root.bindPrefifx = ""
		return true
	}

	Text {
		anchors.centerIn: parent
		text: root.bindPrefix
			? "Vespera Example 2: classic GUI overview"
			: "Vespera Example 2: no device found"
	}
}
