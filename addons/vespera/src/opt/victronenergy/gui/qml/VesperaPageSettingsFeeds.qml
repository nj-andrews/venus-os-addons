pragma ComponentBehavior: Bound
import QtQuick 2
import com.victron.velib 1.0

MbPage {
	id: root
	title: qsTrId("vespera_feeds")
	//tryPop: vesperaManager.tryPop
	pageToolbarHandler: customToolbar

	required property VesperaManager vesperaManager
	property var curPage: pageStack ? (pageStack.currentPage || pageStack.currentItem) : undefined

	onVesperaManagerChanged: root.refreshFeeds()

	VesperaProgressBar {
		text: qsTrId("vespera_loading")
		visible: vesperaManager.running
		anchors.centerIn: parent
		onVisibleChanged: root.listview.visible = !root.vesperaManager.running
	}

	delegate: VesperaHeaderDescriptionItem {
		required property var modelData
		editable: true
		header: formatName(modelData)
		description: "Url: " + modelData.url
		descriptionWrapMode: Text.WrapAtWordBoundaryOrAnywhere
		subpage: modelData.builtin ? undefined : editFeedPageComponent

		Component {
			id: editFeedPageComponent
			VesperaPageSettingsFeedEdit {
				feedModel: vesperaManager.snapshotObject(modelData)
				vesperaManager: root.vesperaManager
				feedUpdatedCallback: root.onFeedUpdated
			}
		}
	}

	function formatName(modelData) {
		return modelData.name
				.replace(/[-_]+/g, " ")
				.replace(/\b\w/g, function(c) { return c.toUpperCase() })
	}

	function refreshFeeds() {
		if (root.vesperaManager == undefined) return

		root.vesperaManager.loadFeeds(false, function(result) {
			if (result.success)
				root.model = result.data
		})
	}

	function onFeedUpdated(refreshFeedName, refreshModelCallback) {
		vesperaManager.loadFeeds(false, function(result) {
			if (result.success) {
				root.model = result.data;
				for (var i = 0; i < root.model.length; i++) {
					if (root.model[i].feedName == refreshFeedName) {
						refreshModelCallback(root.model[i])
						break
					}
				}
			}
		})
	}

	Component {
		id: newFeedPageComponent
		VesperaPageSettingsFeedEdit {}
	}

	ToolbarHandler {
		id: customToolbar
		rightText: qsTrId("vespera_add_new_feed")

		function rightAction() {
			if (root.vesperaManager.running) {
				return
			}

			var feedModel = { name: "", description: "", builtin: false }
			var page = newFeedPageComponent.createObject(pageStack, {
				isNew: true,
				feedModel: feedModel,
				vesperaManager: root.vesperaManager,
				feedUpdatedCallback: root.onFeedUpdated
			})
			if (page) {
				pageStack.push(page)
			}
		}
	}


}
