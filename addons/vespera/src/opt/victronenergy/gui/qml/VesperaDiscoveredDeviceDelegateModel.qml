import QtQuick 2
import com.victron.velib 1.0

MbPage {
	id: root

	model: VesperaSafeDelegateModel {
		property Vespera vespera

		model: VeQItemSortTableModel {
			model: VeQItemTableModel {
				uids: ["dbus/com.victronenergy.vespera/Discovered"]
				flags: VeQItemTableModel.AddChildren |
						VeQItemTableModel.AddNonLeaves |
						VeQItemTableModel.DontAddItem
			}
			filterRegExp: "\/sid_[^/]+$"
			filterFlags: VeQItemSortTableModel.FilterInvalid
		}

		delegate: MbSubMenu {
			id: discoveredDevice
			description: deviceProps.port

			property var deviceProps: JSON.parse(model.item.value)
			property bool deviceAdded: false

			function onDeviceAddedCallback(added) {
				if (started !== undefined) {
					deviceAdded = added
				}

				return added
			}

			subpage: Component {
					VesperaPageDiscoveredDevice {
						vespera: root.vespera
						deviceProps: discoveredDevice.deviceProps
						deviceAddedCallback: discoveredDevice.onDeviceAddedCallback}
				}
			}

	}
}