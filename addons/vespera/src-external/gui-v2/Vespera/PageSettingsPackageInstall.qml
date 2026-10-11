import QtQuick 2
import Victron.VenusOS
import "./components" as Vespera

Page {
	id: root
	tryPop: vesperaManager?.tryPop

	required property var model
	required property Vespera.VesperaManager vesperaManager
	required property var loadPackagesModelCallback
	required property var formatNameCallback

	readonly property bool installed: model.installedVersion?.length > 0
	readonly property bool available: model.availableVersion?.length > 0
	readonly property string actionLabel: installed && available
			//% "Upgrade"
			? qsTrId("vespera_package_upgrade")
			//% "Install"
			: qsTrId("vespera_package_intsall")

	readonly property int hMargin: Theme.geometry_page_content_horizontalMargin + Theme.geometry_listItem_content_horizontalMargin
	readonly property int vMargin: Theme.geometry_listItem_content_verticalMargin

	Column {
		id: column
		anchors {
			top: parent.top
			left: parent.left
			right: parent.right
			topMargin: root.vMargin
		}
		spacing: 0

		// package name, full width
		Label {
			width: parent.width
			leftPadding: root.hMargin
			rightPadding: root.hMargin
			topPadding: root.vMargin
			//bottomPadding: vMargin
			text: formatNameCallback(root.model)
			font.pixelSize: Theme.font_size_body3
			color: Theme.color_font_primary
			wrapMode: Text.Wrap
		}
		// description, full width
		Label {
			width: parent.width
			leftPadding: root.hMargin
			rightPadding: root.hMargin
			topPadding: root.vMargin
			text: root.model.description
			font.pixelSize: Theme.font_size_body2
			color: Theme.color_font_secondary
			wrapMode: Text.Wrap
		}
		// installed / available — wraps when space is insufficient
		// secondary font/color
		Flow {
			width: parent.width
			leftPadding: root.hMargin
			rightPadding: root.hMargin
			topPadding: root.vMargin
			spacing: Theme.geometry_listItem_content_spacing

			// Label 1: Installed
			Row {
				spacing: Theme.geometry_listItem_content_spacing / 2
				Label {
					//% "Installed"
					text: qsTrId("vespera_installed") + ":"
					font.pixelSize: Theme.font_size_body2
					color: Theme.color_font_secondary
				}
				Label {
					text: (root.installed)
							? root.model.installedVersion + (root.model.installedVersionSuffix ? "." + root.model.installedVersionSuffix : "")
							//% "none"
							: qsTrId("vespera_none")
					font.pixelSize: Theme.font_size_body2
					color: Theme.color_font_primary
				}
			}

			// Label 2: Available — flows under Label 1 when not enough space
			Row {
				spacing: Theme.geometry_listItem_content_spacing / 2
				Label {
					//% "Available"
					text: qsTrId("vespera_available")  + ":"
					font.pixelSize: Theme.font_size_body2
					color: Theme.color_font_secondary
				}
				Label {
					text: (root.available)
							? root.model.availableVersion + (root.model.availableVersionSuffix ? "." + root.model.availableVersionSuffix : "")
							//% "none"
							: qsTrId("vespera_none")
					font.pixelSize: Theme.font_size_body2
					color: Theme.color_font_primary
				}
			}
		}

		// Tertiary: feed
		Row {
			id: row
			leftPadding: root.hMargin
			topPadding: root.vMargin
			spacing: Theme.geometry_listItem_content_spacing / 2

			Label {
				//% "Feed"
				text: qsTrId("vespera_feed") + ":"
				font.pixelSize: Theme.font_size_body1
				color: Theme.color_font_secondary
			}
			Label {
				text: root.model.feed
				font.pixelSize: Theme.font_size_body1
				color: Theme.color_font_primary
			}
		}

	}

	Connections {
		target: root.vesperaManager
		function onLog(line) {
			//% "Loading..."
			loadingLabel.text = line && line.length > 0 ? line : qsTrId("vespera_loading")
		}
	}

		ProgressBar {
			id: progressBar
			visible: root.vesperaManager.running
			anchors.top: column.bottom;
			//anchors.topMargin: (actionsRow.y-(column.y+column.height))/2
			anchors.topMargin: 75
			anchors.horizontalCenter: parent.horizontalCenter
			width: parent.width / 2
			indeterminate: true
		}

		Label {
			id: loadingLabel
			anchors.top: progressBar.bottom
			anchors.topMargin: root.vMargin
			anchors.horizontalCenter: parent.horizontalCenter
			visible: progressBar.visible
			font.pixelSize: Theme.font_size_body1
		}

	Vespera.ActionsRow {
		id: actionsRow

		ListItemButton {
			id: btn_remove
			width: actionsRow.defaultButtonWidth
			//% "Remove"
			text: qsTrId("vespera_remove")
			enabled: !root.vesperaManager.running && root.installed && root.model.packageName != "vespera"
			onClicked: function() {
				root.vesperaManager.removePackage(root.model.packageName, completionCallback)
			}
			anchors.right: parent.right
		}

		ListItemButton {
			id: btn_add
			text: root.actionLabel
			width: actionsRow.defaultButtonWidth
			anchors {right: btn_remove.left; rightMargin: actionsRow.spacing}
			enabled: !root.vesperaManager.running && root.available
			onClicked: function() {
				if (!root.installed) {
					root.vesperaManager.installPackage(root.model.packageName, completionCallback)
				} else {
					root.vesperaManager.upgradePackage(root.model.packageName, completionCallback)
				}
			}

		}
		ListItemButton {
			width: actionsRow.defaultButtonWidth
			visible: root.model.enabled != undefined
			anchors {left: parent.left}

			text: root.model.enabled === true ? "Disable" : "Enable"
			enabled: visible && !root.vesperaManager.running && root.installed && root.model.packageName != "vespera"
			onClicked: function() {
					var enabled = root.model.enabled === true
					root.vesperaManager.setPackageEnabledState(root.model.packageName, !enabled, completionCallback)
			}

		}
	}

	function completionCallback(result) {

		if (!result.success)
			return

			root.loadPackagesModelCallback?.(result.data, root.model.packageName, function(updatedModel) {
				root.model = updatedModel
			})
		if (root.vesperaManager.ShowDetailedOutput) {
			logViewer.log("--- Finished " + result.operationName + ". Exit code: " + 	result.exitCode + ", status: " + result.exitStatus + " ---")
		}
	}

}
