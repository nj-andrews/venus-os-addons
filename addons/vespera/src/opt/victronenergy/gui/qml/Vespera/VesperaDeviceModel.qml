pragma Singleton
import QtQuick 2
import com.victron.velib 1.0

QtObject {

	readonly property VeQItemSortTableModel deviceList: VeQItemSortTableModel {
		dynamicSortFilter: true

		filterFlags: VeQItemSortTableModel.FilterOffline
		filterRole: VeQItemTableModel.IdRole
		filterRegExp: "^com\.victronenergy\."

		model: VeQItemTableModel {
			uids: ["dbus"]
			flags: VeQItemTableModel.AddChildren |
						VeQItemTableModel.AddNonLeaves |
						VeQItemTableModel.DontAddItem
		}
	}

}