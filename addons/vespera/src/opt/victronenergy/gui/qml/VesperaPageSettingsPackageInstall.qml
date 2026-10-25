import QtQuick 2
import com.victron.velib 1.0
import "utils.js" as Utils

MbPage {
	id: root
	pageToolbarHandler: customToolbar

	required property var model
	required property VesperaManager vesperaManager
	required property var packageUpdatedCallback

	readonly property bool hasInstalled: model?.installedVersion.length > 0
	readonly property bool hasAvailable: model?.availableVersion.length > 0
	readonly property string actionLabel: hasInstalled && hasAvailable ? qsTrId("vespera_package_upgrade"): !hasInstalled ? qsTrId("vespera_package_install") : ""

	readonly property MbStyle mbStyle: MbStyle {}

	readonly property int hMargin: mbStyle.marginItemHorizontal
	readonly property int vMargin: mbStyle.marginItemVertical
	readonly property var primaryFontColor: root.mbStyle ? root.mbStyle.textColor : "#000000"
	readonly property int secondaryFontSize: Math.round(root.mbStyle.fontPixelSize * 0.8)
	readonly property var secondaryFontColor: mbStyle.color2

	// protect the back button from being pressed while processing commands.
 	MouseArea {
		x:0; y:-mbTools.height
		width: mbTools.height; height: mbTools.height
		visible: vesperaManager.running
	}


	Column {
		id: column
		anchors {
			top: parent.top
			left: parent.left
			right: parent.right
			topMargin: root.vMargin
		}
		spacing: 0

		// Primary: package name, full width
		Label {
			width: parent.width
			leftPadding: root.hMargin
			rightPadding: root.hMargin
			topPadding: root.vMargin
			text: root.title
			color: root.primaryFontColor
			wrapMode: Text.Wrap
		}
		Label {
			width: parent.width
			leftPadding: root.hMargin
			rightPadding: root.hMargin
			topPadding: root.vMargin
			text: root.model?.description
			color: root.primaryFontColor
			font.pixelSize: root.secondaryFontSize
			wrapMode: Text.Wrap
		}
		// Secondary: installed / available — wraps when space is insufficient
		Flow {
			width: parent.width
			leftPadding: root.hMargin
			rightPadding: root.hMargin
			topPadding: root.vMargin
			spacing: mbStyle.marginItemHorizontal

			// Label 1: Installed
			Row {
				spacing: mbStyle.marginItemHorizontal
				Label {
					text: qsTrId("vespera_installed") + ":"
					font.pixelSize: root.secondaryFontSize
					color: root.secondaryFontColor
				}
				Label {
					text: (root.hasInstalled)
							? root.model?.installedVersion + (root.model.installedVersionSuffix ? "." + root.model.installedVersionSuffix : "")
							: qsTranslate("MbItemSmartLithiumError", "None")
					font.pixelSize: root.secondaryFontSize
					color: root.primaryFontColor
				}
			}

			// Label 2: Available
			Row {
				rightPadding: root.hMargin
				spacing: mbStyle.marginItemHorizontal
				Label {
					text: qsTrId("vespera_available") + ":"
					font.pixelSize: root.secondaryFontSize
					color: root.secondaryFontColor
				}
				Label {
					text: (root.hasAvailable)
							? root.model?.availableVersion + (root.model.availableVersionSuffix ? "." + root.model.availableVersionSuffix : "")
							: qsTranslate("MbItemSmartLithiumError", "None")
					font.pixelSize: root.secondaryFontSize
					color: root.primaryFontColor
				}
			}
			Row {
				id: row
				rightPadding: root.hMargin
				spacing: mbStyle.marginItemHorizontal

				Label {
					text: qsTrId("vespera_feed") + ":"
					font.pixelSize: root.secondaryFontSize
					color: root.secondaryFontColor
				}
				Label {
					text: root.model?.feed
					font.pixelSize: root.secondaryFontSize
					color: root.primaryFontColor
				}
			}
		}

	}

	VesperaProgressBar {
		id: progressBar
		visible: root.vesperaManager.running
		text: root.vesperaManager.running ? root.vesperaManager.logLine : ""
		anchors {
			top: column.bottom; topMargin: root.vMargin
			bottom: parent.bottom; bottomMargin: root.vMargin
			left: parent.left; leftMargin: root.hMargin
			right: parent.right; rightMargin: root.hMargin
		}
	}

		MbOK {
			id: scanItem
			anchors.bottom: root.bottom
			description: qstr("State")
			enabled: !root.vesperaManager.running
			visible: root.model.enabled != undefined && root.model.packageName != "vespera"
			value: root.model.enabled === true
				//% "Disable"
				? qsTrId("vespera_disable")
				//% "Enable"
				: qsTrId("vespera_enable")
			onClicked: function() {
				if (!enabled) return
				var appEnabled = root.model.enabled === true
				root.vesperaManager.setPackageEnabledState(root.model.packageName, !appEnabled, completionCallback)
			}

		}


	ToolbarHandler {
		id: customToolbar
		leftText: root.model && !root.vesperaManager.running && root.hasInstalled && root.model.packageName != "vespera" ? qsTrId("vespera_remove") : ""
		function leftAction() {
			root.vesperaManager.removePackage(root.model.packageName, completionCallback)
		}

		rightText: root.actionLabel
		function rightAction() {
			/*
			// test model update
			var updatedModel = {
					packageName: "New Package",
					description: "My new description",
					installedVersion: "5.2",
					availableVersion: "6.2", feed:"test-feed" }
			root.model = updatedModel
			return
			*/

			if (!root.hasInstalled) {
				root.vesperaManager.installPackage(root.model.packageName, completionCallback)
			} else {
				root.vesperaManager.upgradePackage(root.model.packageName, completionCallback)
			}
		}
	}

	function completionCallback(result) {
		if (!result.success) return

		root.packageUpdatedCallback?.(root.model.packageName, function(updatedModel) {
			root.model = updatedModel
		})
	}

}
