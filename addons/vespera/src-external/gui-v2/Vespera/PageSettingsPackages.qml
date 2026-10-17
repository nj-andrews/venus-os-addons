import QtQuick 2
import Victron.VenusOS
import "qrc:/Vespera/components" as Vespera

Page {
	id: root
	//% "Packages"
	title: qsTrId("vespera_packages")
	tryPop: vesperaManager?.tryPop

	required property Vespera.VesperaManager vesperaManager

	Component.onCompleted: root.refreshPackages()

	Vespera.ProgressText {id: progressText}

	Label {
		id: loadingLabel
		//% "Loading..."
		text: qsTrId("vespera_loading")
		visible: root.vesperaManager.running
		anchors.centerIn: parent
		font.pixelSize: Theme.font_size_body3
	}
	ProgressBar {
		visible: root.vesperaManager.running
		width: parent.width / 2
		anchors.horizontalCenter: parent.horizontalCenter
		anchors.top: loadingLabel.bottom
		indeterminate : true
	}
	GradientListView {
		id: packagesListview
		clip: true
		visible : !root.vesperaManager.running
		anchors { top: parent.top; left: parent.left; right: parent.right; bottom: actionsRow.top }

		delegate: ListNavigation {
			required property var modelData
			showAccessLevel: VenusOS.User_AccessType_User
			writeAccessLevel: VenusOS.User_AccessType_Installer

			readonly property color _baseIndicatorColor: (modelData.installedVersion && modelData.availableVersion
											? Theme.color_orange
											: (modelData.installedVersion
													? Theme.color_blue
													: Qt.rgba(0,0,0,0)))

			VeQuickItem {
				id: packageEnabled
				uid: modelData.dbusKeyName ? Global.systemSettings.serviceUid + "/Settings/Vespera/Packages/" + modelData.dbusKeyName +"/Enabled": ""
				onValueChanged: { modelData.enabled = (value == 1) }
			}

			indicatorColor: modelData.enabled === false
							 ? Qt.rgba(_baseIndicatorColor.r, _baseIndicatorColor.g, _baseIndicatorColor.b, _baseIndicatorColor.a * 0.5)
							 : _baseIndicatorColor
			text: root.formatName(modelData)
			caption: modelData.description
			onClicked: {
				if (!Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)) {
					Global.showToastNotification(VenusOS.Notification_Info, qsTrId("listItem_no_access"))
					return
				}
				Global.pageManager.pushPage(
					"qrc:/Vespera/PageSettingsPackageInstall.qml",
					{ title: text,
						vesperaManager: root.vesperaManager,
						model: root.vesperaManager.snapshotObject(modelData),
						packageUpdatedCallback: root.onPackageUpdated,
						formatNameCallback: formatName}
				)
			}
		}
	}

	function formatName(model) {
    return model.packageName
        .replace(/[-_]+/g, " ")
        .replace(/\b\w/g, function(c) { return c.toUpperCase() })
				+ "  " + model.installedVersion
	}
	function refreshPackages(update) {
		root.vesperaManager.loadPackages(update, function(result) {
			if (result.success)
				packagesListview.model = result.data;
		})
	}

	function onPackageUpdated(refreshPackageName, refreshModelCallback) {
		vesperaManager.loadPackages(false, function(result) {
				if (result.success)
					packagesListview.model = result.data;
					for (var i = 0; i < packagesListview.model.length; i++) {
						if (packagesListview.model[i].packageName == refreshPackageName) {
							refreshModelCallback(packagesListview.model[i])
							break
						}
					}
			})
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