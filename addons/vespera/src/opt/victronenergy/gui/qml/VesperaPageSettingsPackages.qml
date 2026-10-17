pragma ComponentBehavior: Bound
import QtQuick 2

MbPage {
	id: root
	title: qsTrId("vespera_packages")
	//tryPop: vesperaManager.tryPop
	pageToolbarHandler: customToolbar

  property VesperaManager vesperaManager
	property var test
	property var curPage: pageStack ? (pageStack.currentPage || pageStack.currentItem) : undefined
	property var packagesModel: []
	property MbStyle mbStyle: MbStyle {}

	onVesperaManagerChanged: root.refreshPackages()

	VesperaProgressBar {
		text: qsTrId("vespera_loading")
		visible: vesperaManager.running
		anchors.centerIn: parent
		onVisibleChanged: root.listview.visible = !vesperaManager.running
	}

	delegate: VesperaHeaderDescriptionItem {
		required property var modelData

		VeQuickItem {
			id: packageEnabled
			uid: modelData.dbusKeyName ? "dbus/com.victronenergy.settings/Settings/Vespera/Packages/" + modelData.dbusKeyName + "/Enabled": ""
			onValueChanged: { modelData.enabled = (value == 1) }
		}

		id: headerItem
		header: root.formatName(modelData)
		description: modelData.description

		readonly property color _baseIndicatorColor: (modelData.installedVersion && modelData.availableVersion
										? Qt.color("orange")
										: (modelData.installedVersion
												? Qt.color('#055194')
												: Qt.rgba(0,0,0,0)))

		indicatorColor: modelData.enabled === false
							? Qt.rgba(_baseIndicatorColor.r, _baseIndicatorColor.g, _baseIndicatorColor.b, _baseIndicatorColor.a * 0.5)
							: _baseIndicatorColor

		subpage: Component {
			VesperaPageSettingsPackageInstall {
				title: header
				vesperaManager: root.vesperaManager
				model: root.vesperaManager.snapshotObject(modelData)
				packageUpdatedCallback: root.onPackageUpdated}
		}
	}

	function formatName(model) {
    return model.packageName
        .replace(/[-_]+/g, " ")
        .replace(/\b\w/g, function(c) { return c.toUpperCase() })
				+ "  " + model.installedVersion
	}

	function refreshPackages(update) {
		if (vesperaManager == undefined) return
		vesperaManager.loadPackages(update, function(result) {
			if (result.success)
				root.model = result.data;
		})
	}

	function onPackageUpdated(refreshPackageName, refreshModelCallback) {
		vesperaManager.loadPackages(false, function(result) {
				if (result.success) {
					root.model = result.data;
					for (var i = 0; i < root.model.length; i++) {
						if (root.model[i].packageName == refreshPackageName)
							refreshModelCallback(root.model[i])
					}
				}
			})
	}

	ToolbarHandler {
		id: customToolbar
		leftText: qsTrId("vespera_refresh")
		function leftAction(mouse) {
			if (!mouse || root.vesperaManager.running) return
			refreshPackages(true)
		}

	}

}