import QtQuick 2
import Victron.VenusOS

//Gets all the child nodes of specified name (Role)
// under the provided path (uid);
// using an optional filter on the uid
// Will update the rows on changes
// Use onRowCountChanged to monitor changes
// Use rowCount to get the count of items
// In delegates use model.value to get the value of the childId
// i.e. if childId is "ProductName" value will return "Foo Product"
// Use model.buddy to get the parent node
//   model.buddy.uid for the path, model.buddy.id for the path name

VeQItemSortTableModel {
	id: root

	property alias childId: childModel.childId
	property string uid
	property alias filterRegExp: sortTable.filterRegExp
 	property var valueDelegate

	model: VeQItemChildModel {
		id: childModel
		model: VeQItemSortTableModel {
			id: sortTable
			model: VeQItemTableModel {
				uids: [root.uid]
				flags: VeQItemTableModel.AddChildren |
						VeQItemTableModel.AddNonLeaves |
						VeQItemTableModel.DontAddItem
			}
			dynamicSortFilter: true
			filterFlags: VeQItemSortTableModel.FilterOffline
		}

	}
	dynamicSortFilter: true
	filterFlags: VeQItemSortTableModel.FilterInvalid

}