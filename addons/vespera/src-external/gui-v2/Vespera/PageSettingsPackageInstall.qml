import QtQuick 2
import Victron.VenusOS
import "./components" as Vespera

Page {
	id: root
	tryPop: vesperaManager?.tryPop

	required property var model
	required property Vespera.VesperaManager vesperaManager
	required property var packageUpdatedCallback
	required property var formatNameCallback

	readonly property bool vespera_running: root.vesperaManager && root.vesperaManager.running
	readonly property bool installed: model.installedVersion?.length > 0
	readonly property bool available: model.availableVersion?.length > 0
	readonly property string actionLabel: installed && available
			//% "Upgrade"
			? qsTrId("vespera_package_upgrade")
			//% "Install"
			: qsTrId("vespera_package_install")

	readonly property int hMargin: Theme.geometry_page_content_horizontalMargin + Theme.geometry_listItem_content_horizontalMargin
	readonly property int vMargin: Theme.geometry_listItem_content_verticalMargin

	Column {
		id: column
		anchors {top: parent.top; left: parent.left; right: parent.right; topMargin: root.vMargin}
		spacing: 0

		// package name, full width
		Label {
			width: parent.width
			leftPadding: root.hMargin; rightPadding: root.hMargin; topPadding: root.vMargin
			//bottomPadding: vMargin
			text: root.formatNameCallback(root.model)
			font.pixelSize: Theme.font_size_body3
			color: Theme.color_font_primary
			wrapMode: Text.Wrap
		}
		// description, full width
		Label {
			width: parent.width
			leftPadding: root.hMargin; rightPadding: root.hMargin; topPadding: root.vMargin
			text: root.model.description
			font.pixelSize: Theme.font_size_body2
			color: Theme.color_font_secondary
			wrapMode: Text.Wrap
		}
		// installed / available — wraps when space is insufficient
		// secondary font/color
		Flow {
			width: parent.width
			leftPadding: root.hMargin; rightPadding: root.hMargin; topPadding: root.vMargin
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
							: qsTrId("vespera_none")
					font.pixelSize: Theme.font_size_body2
					color: Theme.color_font_primary
				}
			}

			// Label 2: Available — flows under Label 1 when space is restricted
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
							: qsTrId("vespera_none")
					font.pixelSize: Theme.font_size_body2
					color: Theme.color_font_primary
				}
			}
		}

		// Tertiary: feed
		Row {
			id: row
			leftPadding: root.hMargin; topPadding: root.vMargin
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

	ProgressBar {
		id: progressBar
		visible: root.vespera_running

		anchors {top: column.bottom;topMargin: 75; horizontalCenter: parent.horizontalCenter}
		width: parent.width / 2
		indeterminate: true
	}

	Label {
		id: loadingLabel
		text: root.vespera_running ? root.vesperaManager.logLine : ""
		anchors {top: progressBar.bottom; topMargin: root.vMargin; horizontalCenter: parent.horizontalCenter}
		visible: progressBar.visible
		font.pixelSize: Theme.font_size_body1
	}

	Vespera.ActionsRow {
		id: actionsRow

		ListItemButton {
			id: btn_remove
			width: actionsRow.defaultButtonWidth
			text: CommonWords.remove
			enabled: !vespera_running && root.installed && root.model.packageName != "vespera" && Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)
			onClicked: function() {
				if (!vesperaManager.installerAccess) return
				root.vesperaManager.removePackage(root.model.packageName, completionCallback)
			}
			anchors.right: parent.right
		}

		ListItemButton {
			id: btn_add
			text: root.actionLabel
			width: actionsRow.defaultButtonWidth
			anchors {right: btn_remove.left; rightMargin: actionsRow.spacing}
			enabled: !vespera_running && root.available && Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)
			onClicked: function() {
				if (!vesperaManager.installerAccess) return
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

			text: root.model.enabled === true
				//% "Disable"
				? qsTrId("vespera_disable")
				//% "Enable"
				: qsTrId("vespera_enable")

			enabled: visible && !vespera_running && root.installed && root.model.packageName != "vespera" && Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)
			onClicked: function() {
				if (!vesperaManager.installerAccess) return
				var enabled = root.model.enabled === true
				root.vesperaManager.setPackageEnabledState(root.model.packageName, !enabled, completionCallback)
			}

		}
	}

	function completionCallback(result) {
		if (!result.success || result.data === undefined) return

		root.packageUpdatedCallback?.(root.model.packageName, function(updatedModel) {
			root.model = updatedModel
		})
	}

}
