import QtQuick 2
import Victron.VenusOS
import "qrc:/Vespera/components" as Vespera

Page {
	id: page
	title: "Vespera"
	Component.onDestruction: vesperaManager?.cleanup()

	Vespera.VesperaManager { id: vesperaManager; traceEnabled: true }

	function dummy_v1_gui_translations() {
		//% "Move settings to top"
		_ = qsTrId("vespera_move_settings_to_top")
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
					if (!vesperaManager.installerAccess()) return
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
					if (!vesperaManager.installerAccess()) return
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
					if (!vesperaManager.installerAccess()) return
					Global.pageManager.pushPage("qrc:/Vespera/PageSettingsDevicesList.qml", {
						title: text, vesperaManager: vesperaManager })
				}
			}

			ListLink {
				text: qsTrId("pagecontrollableloads_documentation")
				url: "https://thespinmaster.github.io/venus-os-addons/"
			}
			ListText {
				// bug "displays "Documentation" not "Application version"
				// text: qsTrId("settings_page_debug_application_version")
				secondaryText: GuiPluginLoader.plugin("Vespera").version
			}
		}
	}
}
