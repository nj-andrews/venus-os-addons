import QtQuick 2
import Victron.VenusOS
import "./components" as Vespera

Page {
	id: root
	//% "Feeds"
	title: qsTrId("vespera_feeds")
	tryPop: vesperaManager?.tryPop

	required property Vespera.VesperaManager vesperaManager

	Component.onCompleted: refreshFeeds()

	Label {
		id: loadingLabel
		//% "Loading..."
		text: qsTrId("vespera_loading")
		visible: root.vesperaManager.running
		anchors.centerIn: parent
		font.pixelSize: Theme.font_size_body3
	}
	ProgressBar {
		id: progressBar
		visible: root.vesperaManager.running
		width: parent.width / 2
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.top: loadingLabel.bottom
		indeterminate : true
	}

	GradientListView {
		id: feedsListView
		visible: !root.vesperaManager.running
		clip: true
		anchors.fill: parent
		anchors { 	top: parent.top; left: parent.left; right: parent.right; bottom: actionsRow.top; }
		delegate: ListNavigation {
			required property var modelData

			showAccessLevel: VenusOS.User_AccessType_User
			writeAccessLevel: VenusOS.User_AccessType_Installer
			text: root.formatName(modelData)
			caption: modelData.url
			hasSubMenu: false
			iconSource: modelData.builtin ? "" : "qrc:/images/icon_chevron_right_32.svg"
			onClicked: {
				if (modelData.builtin) return
				if (!vesperaManager.installerAccess) return
				Global.pageManager.pushPage("qrc:/Vespera/PageSettingsFeedEdit.qml", {
						title: modelData.name,
						vesperaManager: root.vesperaManager,
						model: modelData,
						feedUpdatedCallback : root.onFeedUpdated
					}
				)
			}
		}
	}

	function formatName(modelData) {
    return modelData.name
				.replace(/[-_]+/g, " ")
        .replace(/\b\w/g, function(c) { return c.toUpperCase() })
	}

	function refreshFeeds() {
		root.vesperaManager.loadFeeds(false, function(result) {
			if (result.success)
				feedsListView.model = result.data
		})
	}

	function onFeedUpdated(refreshFeedName, refreshModelCallback) {
		vesperaManager.loadFeeds(false, function(result) {
				if (result.success) {
					feedsListView.model = result.data;
					for (var i = 0; i < feedsListView.model.length; i++) {
						if (feedsListView.model[i].feedName == refreshFeedName) {
							refreshModelCallback(feedsListView.model[i])
							break
						}
					}
				}
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
				if (!root.installerAccess) return
				Global.pageManager.pushPage("qrc:/Vespera/PageSettingsFeedEdit.qml", {
						title: qsTrId("vespera_add_new_feed"),
						vesperaManager: root.vesperaManager,
						model: {name:"", url:"", builtin: false, isNew: true},
						loadFeedsModelCallback: root.onFeedUpdated})
			}
		}
	}

}