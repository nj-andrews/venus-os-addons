pragma ComponentBehavior: Bound
import QtQuick 2
import com.victron.velib 1.0

MbPage {
	id: root
	title: qsTrId("vespera_edit_feed")
	pageToolbarHandler: customToolbar

	required property var feedModel
	required property VesperaManager vesperaManager
	required property var feedUpdatedCallback
	property bool isNew: false
	property string _removeButtonText: isNew ? qsTrId("vespera_cancel") : qsTrId("vespera_remove")
	property string _saveButtonText: qsTrId("vespera_save")

	model: VisibleItemModel {
		MbEditBox {
			id: feedNameTextField
			readonly: !userHasWriteAccess || (isNew ? false : feedModel?.builtin ?? true)
			useVirtualKeyboard: false
			description: qsTrId("vespera_feed_name")
			maximumLength: 20
			enableSpaceBar: false
			item.value: (!isNew && root.feedModel) ? feedModel.name : ""
		}

		VesperaEditBoxLargeText {
			id: feedUrlTextField
			readonly: !userHasWriteAccess || (isNew ? false : feedModel?.builtin ?? true)
			description: qsTrId("vespera_feed_url")
			maximumLength: 256
			matchString: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ~!@#$%^&*()-_=+[]{}\\;:|/.,<>?"
			enableSpaceBar: false
			item.value:  (!isNew && root.feedModel) ? feedModel.url : ""
		}
	}

	ToolbarHandler {
		id: customToolbar
		//leftIcon: (feedModel?.builtin) ? "" : "icon-toolbar-cancel"
		//rightIcon: (feedModel?.builtin) ? "" :"icon-toolbar-ok"
		leftText: !feedModel.builtin ? root._removeButtonText : ""
		function leftAction() {
			if (root.isNew) {
				pageStack.pop()
			} else {
				root.remove()
			}
		}
		rightText: !feedModel.builtin ? root._saveButtonText : ""
		function rightAction() {root.save()}
	}

	function remove() {
		if (root._builtin || vesperaManager.running)
			return

		var completedCallback = function(result) {
			if (!result.success) {
				root._removeButtonText = qsTrId("vespera_remove")
				return
			}

			feedUpdatedCallback?.(result.data)
			pageStack.pop()
		}

		root._removeButtonText = qsTrId("vespera_removing")
		vesperaManager.removeFeed(root.model.name, completedCallback)

	}

	function save() {
		if (root._builtin || vesperaManager.running)
			return

		var status1 = root.validateFeedName()
		var status2 = root.validateFeedUrl()
		var error = status1 && status2
			? status1 + "\n  " + status2
			: status1
				? status1
				: status2

		if (error) {
			toast.createToast(error, 3000, "icon-info-active");
			return
		}

		var feedName = feedNameTextField.text
		var feedUrl = feedUrlTextField.text

		var completedCallback = function(result) {
			if (!result.success) {
				root._saveButtonText = qsTrId("vespera_save")
				return
			}
			root.title = feedName // update breadcrumb
			root._isNew = false
			feedUpdatedCallback?.(feedName, root.refreshModel)

		}

		root._saveButtonText = qsTrId("vespera_saving")

		if (root._isNew) {
			vesperaManager.addFeed(feedName, feedUrl, completedCallback)
		} else {
			vesperaManager.updateFeed(feedName, feedUrl, model.name, completedCallback)
		}
	}


	function validateFeedName() {
		var text = feedNameTextField.text
		console.log("validateFeedName:" + text)
		// only alphanumeric, no spaces or symbols
		// must contain at least one letter (prevents "12345")
		if (!/^[A-Za-z0-9-]+$/.test(text) || (!/[A-Za-z]/.test(text))) {
			//% "'%1' is not a valid IP address."
			// qsTrId("ip_address_input_not_valid").arg(trimmed)
			return "Invalid Name"
		}
		return
	}

	function validateFeedUrl() {
		console.log("validateFeedUrl: in")
		var text = feedUrlTextField.text
		const pattern = /^https?:\/\/([a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*|\d{1,3}(\.\d{1,3}){3})(:\d+)?(\/.*)?$/;
		if (!pattern.test(text)) {
			//% "'%1' is not a valid IP address."
			// qsTrId("ip_address_input_not_valid").arg(trimmed)
			return "Invalid URL"
		}

		return
	}
}