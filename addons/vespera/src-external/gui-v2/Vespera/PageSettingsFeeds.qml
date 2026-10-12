import QtQuick 2
import Victron.VenusOS
import "./components" as Vespera

Page {
	id: root
	//% "Feeds"
	title: qsTrId("vespera_feeds")
	tryPop: vesperaManager.tryPop

	required property Vespera.VesperaManager vesperaManager
	property bool _loading

	Component.onCompleted: refreshFeeds()

	function installerAccess() {
		//% "No access"
		if (Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)) return true
		Global.showToastNotification(VenusOS.Notification_Info, qsTrId("listItem_no_access"))
	}

	ProgressBar {
		id: progressBar
		visible: loadingLabel.visible
		width: parent.width / 2
		anchors {horizontalCenter: parent.horizontalCenter ; centerIn: parent}
		indeterminate : true
	}
	Label {
		id: loadingLabel
		//% "Loading..."
		text: qsTrId("vespera_loading")
		visible: root._loading
		anchors.top: progressBar.bottom
		font.pixelSize: Theme.font_size_body3
	}

	GradientListView {
		id: settingsListView
		clip: true
		anchors.fill: parent
		anchors { 	top: parent.top; left: parent.left; right: parent.right; bottom: actionsRow.top; }
		delegate: ListNavigation {
			required property var modelData

			showAccessLevel: VenusOS.User_AccessType_User
			writeAccessLevel: VenusOS.User_AccessType_Installer
			text: formatName(modelData)
			caption: modelData.url

			onClicked: {
				if (!installerAccess) return
				Global.pageManager.pushPage("qrc:/Vespera/PageSettingsFeedEdit.qml", {
						title: modelData.name,
						vesperaManager: root.vesperaManager,
						model: modelData,
						loadFeedsModelCallback: root.loadFeeds
					}
				)
			}
		}
	}

	function formatName(modelData) {
    return modelData.name.replace(/[-_]+/g, " ")
        .replace(/\b\w/g, function(c) { return c.toUpperCase() })
	}

	function loadFeeds(feeds, refreshFeedName, refreshModelCallback) {
		settingsListView.model = feeds
		// Refresh the model
		if (refreshModelCallback)
			for (var i = 0; i < feeds.length; i++) {
				if (feeds[i].name == refreshFeedName) {
					refreshModelCallback(feeds[i])}
		}
	}

	function refreshFeeds() {
		_loading = true
		root.vesperaManager.loadFeeds(false, function(result) {
			if (result.success)
				loadFeeds(result.data)
			_loading = false
		})
	}
	Vespera.ActionsRow {
		id: actionsRow
		ListItemButton {
			//% "Add New Feed"
			text: qsTrId("vespera_add_new_feed")
			anchors {right: parent.right}
			enabled: Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)
			onClicked: function() {
				if (!installerAccess) return
				Global.pageManager.pushPage("qrc:/Vespera/PageSettingsFeedEdit.qml", {
						title: qsTrId("vespera_add_new_feed"),
						vesperaManager: root.vesperaManager,
						model: {name:"", url:"", builtin: false, isNew: true},
						loadFeedsModelCallback: root.loadFeeds})
			}
		}
	}

}