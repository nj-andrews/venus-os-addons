import QtQuick 2
import Victron.VenusOS
import "qrc:/Vespera/components" as Vespera

Page {
	id: root
	//% "Packages"
	title: qsTrId("vespera_packages")
	tryPop: vesperaManager.tryPop

	required property Vespera.VesperaManager vesperaManager
	property bool _loading: true

	Component.onCompleted: root.refreshPackages()

	Vespera.ProgressText {id: progressText}

	Label {
		id: loadingLabel
		//% "Loading..."
		text: qsTrId("vespera_loading")
		visible: root._loading
		anchors.centerIn: parent
		font.pixelSize: Theme.font_size_body3
	}
	ProgressBar {
		visible: loadingLabel.visible
		width: parent.width / 2
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.top: loadingLabel.bottom
		indeterminate : true
	}
	GradientListView {
		id: settingsListView
		clip: true
		visible : !root._loading
		anchors {
			top: parent.top
			left: parent.left
			right: parent.right
			bottom: actionsRow.top
		}

		delegate: ListNavigation {
			required property var modelData

			indicatorColor: (modelData.installedVersion && modelData.availableVersion
											? Theme.color_orange
											: (modelData.installedVersion
													? Theme.color_blue
													: Qt.rgba(0,0,0,0)))
			text: formatName(modelData)
			caption: root.vesperaManager.showCompact ? "" : modelData.description
			onClicked: Global.pageManager.pushPage(
				"qrc:/Vespera/PageSettingsPackageInstall.qml",
				{ title: text,
					vesperaManager: root.vesperaManager,
					model: root.vesperaManager.snapshotObject(modelData),
					loadPackagesModelCallback: root.onLoadPackagesModel,
					formatNameCallback: formatName}
			)
		}
	}

	function formatName(modelData) {
    return modelData.packageName
        .replace(/[-_]+/g, " ")
        .replace(/\b\w/g, function(c) { return c.toUpperCase() })
				+ "  " + modelData.installedVersion
	}
	function refreshPackages(update) {
		_loading = true
		vesperaManager.loadPackages(update, function(result) {
				if (result.success)
					onLoadPackagesModel(result.data)
				_loading = false
			})
	}

	function onLoadPackagesModel(packages, refreshPackageName, refreshModelCallback) {
		settingsListView.model = packages;

		// Refresh the model (from PageSettingsPackageInstall.qml)
		if (refreshModelCallback)
			for (var i = 0; i < packages.length; i++) {
				if (packages[i].packageName == refreshPackageName) {
					refreshModelCallback(packages[i])}
		}
	}

	Vespera.ActionsRow {
		id: actionsRow
		ListItemButton {
			id: btn_refresh
			width: actionsRow.defaultButtonWidth
			anchors {right: parent.right}
			//% "Refresh"
			text: qsTrId("vespera_refresh")
			enabled: root.vesperaManager ? (!root.vesperaManager.running && visible) : false
			onClicked: function() {
				root.refreshPackages(true)
			}
		}
	}

}