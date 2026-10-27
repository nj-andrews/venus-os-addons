import QtQuick 2
import Victron.VenusOS

Page {
	id: root
	//% "Inetbox settings"
	title: qsTrId("inetbox_settings")

	property var pageUri:"qrc:/Inetbox/MotorhomePage.qml"
	property var customPages: customPagesItem.valid ? customPagesItem.value.split(',') : []
	property string app: qsTrId("settings_page_debug_application_version")

	VeQuickItem {
		id: customPagesItem
		uid: !!Global.systemSettings ? Global.systemSettings.serviceUid + "/Settings/Vespera/CustomNavPages" : ""
	}

	GradientListView {
		id: settingsListView

		model: VisibleItemModel {

			ListSwitch {
				id: show_mh_page_switch
				checkable: true
				checked: root.customPages.includes(root.pageUri)

				//% "Show Motorhome Page"
				text: qsTrId("inetbox_show_motorhome_page")
				writeAccessLevel: VenusOS.User_AccessType_User

				onCheckedChanged: {
					const idx = root.customPages.indexOf(root.pageUri)
					if (checked) {
						if (idx !== -1) return
						root.customPages.push(root.pageUri)
					} else {
						if (idx === -1) return
						root.customPages.splice(idx, 1)
					}

					customPagesItem.setValue(root.customPages)
				}
			}

			ListLink {
				text: qsTrId("pagecontrollableloads_documentation")
				url: "https://nj-andrews.github.io/venus-os-addons/"
			}
			ListText {
				secondaryText: GuiPluginLoader.plugin("Inetbox").version
			}

		}
	}

}
