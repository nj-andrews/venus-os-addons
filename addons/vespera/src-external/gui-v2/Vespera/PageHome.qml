import QtQuick 2
import Victron.VenusOS
import "qrc:/Vespera/components" as Vespera

Page {
	id: page
	//% "Vespera Package Manager"
	title: qsTrId("vespera_open_package_manager")
	Component.onDestruction: vesperaManager?.cleanup()

	Vespera.VesperaManager {
		id: vesperaManager
		traceEnabled: true
		function showToastNotification(level, message, duration) {
			Global.showToastNotification(level, message, duration)
			// console.log("vespera:" + level + ", " + message)
		}
	}

	GradientListView {
		id: settingsListView

		model: VisibleItemModel {
			ListNavigation {
				//% "Packages"
				text: qsTrId("vespera_packages")
				onClicked: Global.pageManager.pushPage("qrc:/Vespera/PageSettingsPackages.qml", {
						title: text, vesperaManager: vesperaManager })
			}
			ListNavigation {
				//% "Feeds"
				text: qsTrId("vespera_feeds")
				onClicked: Global.pageManager.pushPage("qrc:/Vespera/PageSettingsFeeds.qml", {
						title: text, vesperaManager: vesperaManager })
			}

			ListNavigation {
				topInset: Theme.geometry_listItem_itemSeparator_height
				bottomInset: Theme.geometry_listItem_itemSeparator_height
				//% "Custom Devices"
				text: qsTrId("vespera_custom_devices")
				onClicked: Global.pageManager.pushPage("qrc:/Vespera/PageSettingsDevicesList.qml", {
						title: text, vesperaManager: vesperaManager })
			}
			// ListNavigation {
			// 	//% "Settings"
			// 	text: qsTrId("vespera_settings")
			// 	onClicked: Global.pageManager.pushPage("qrc:/Vespera/PageSettings.qml", {title: text,vesperaManager: vesperaManager})
			// }
			ListLink {
				//% "Documentation"
				text: qsTrId("pagecontrollableloads_documentation")
				url: "https://thespinmaster.github.io/venus-os-addons/"
			}
			ListText {
				//% "Version"
				text: qsTrId("vespera_version")
				secondaryText: GuiPluginLoader.plugin("Vespera").version
			}
		}
	}
}
