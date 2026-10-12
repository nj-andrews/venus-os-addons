import QtQuick 2
import Victron.VenusOS
import "qrc:/Vespera/components" as Vespera

Page {
	id: page
	title: "Vespera"
	Component.onDestruction: vesperaManager?.cleanup()

	Vespera.VesperaManager { id: vesperaManager; traceEnabled: true }
	
	function installerAccess() {
		//% "No access"
		if (Global.systemSettings.canAccess(VenusOS.User_AccessType_Installer)) return true
		Global.showToastNotification(VenusOS.Notification_Info, qsTrId("listItem_no_access"))
	}

	GradientListView {
		id: settingsListView

		model: VisibleItemModel {
			ListNavigation {
				//% "Packages"
				text: qsTrId("vespera_packages")
				showAccessLevel: VenusOS.User_AccessType_User
				writeAccessLevel: VenusOS.User_AccessType_Installer
				onClicked: {
					if (!installerAccess()) return
					Global.pageManager.pushPage("qrc:/Vespera/PageSettingsPackages.qml", {
						title: text, vesperaManager: vesperaManager })
				}
			}
			ListNavigation {
				//% "Feeds"
				text: qsTrId("vespera_feeds")
				showAccessLevel: VenusOS.User_AccessType_User
				writeAccessLevel: VenusOS.User_AccessType_Installer
				onClicked: {
					if (!installerAccess()) return
					Global.pageManager.pushPage("qrc:/Vespera/PageSettingsFeeds.qml", {
						title: text, vesperaManager: vesperaManager })
				}
			}

			ListNavigation {
				topInset: Theme.geometry_listItem_itemSeparator_height
				bottomInset: Theme.geometry_listItem_itemSeparator_height
				//% "Custom Devices"
				text: qsTrId("vespera_custom_devices")
				showAccessLevel: VenusOS.User_AccessType_User
				writeAccessLevel: VenusOS.User_AccessType_Installer
				onClicked: {
					if (!installerAccess()) return
					Global.pageManager.pushPage("qrc:/Vespera/PageSettingsDevicesList.qml", {
						title: text, vesperaManager: vesperaManager })
				}
			}
			// ListNavigation {
			// 	//% "Settings"
			// 	text: qsTrId("vespera_settings")
			// 	onClicked: Global.pageManager.pushPage("qrc:/Vespera/PageSettings.qml", {title: text,vesperaManager: vesperaManager})
			// }
			ListLink {
				//: "Documentation"
				text: qsTrId("pagesettingsgeneral_documentation")
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
