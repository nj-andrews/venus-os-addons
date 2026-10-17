
.pragma library

function initCreateComponent(customItems) {

  if (customItems.value === undefined)
    return

  for (var path in customItems.value) {
    var parts = path.split("/");
    var qmlItemName = parts[parts.length - 1]; // "OpkgPageSettingsSubMenu"
    //console.log("caching:" + qmlItemName + ".qml")
    var cmo = Qt.createComponent(qmlItemName + ".qml")
    cmo.destroy()
  }

}

function qmlFileExists(qmlFileName) {
  var component = Qt.createComponent(qmlFileName)
  var exists = component.status === 1

  if (!exists) {
    console.log("vespera: QML file not found or invalid: " + qmlFileName)
    console.log(component.errorString())
  }

  component.destroy()
  return exists
}

//functionality
// actions:
// "" : empty/undefined (add to end)
// ^  : add at top (value is string) (top) (insert 0)
// +  : add before item name (value is name) (insert index)
// *  : replace item (value starts with "+")  (insert index)
// -  : remove item (value starts with "-")  (remove index)
function addRemoveCustomItems(customItems, model, componentFactoryCallback, itemIndexCallback) {
  if (!customItems.valid || customItems.value.length === 0) {
    return;
  }
  addRemoveCustomItemsQuick(customItems, model, componentFactoryCallback, itemIndexCallback)
}

function addRemoveCustomItemsQuick(customItems, model, componentFactoryCallback, itemIndexCallback) {

  if (customItems == undefined)
    return

	if (itemIndexCallback == undefined)
		throw new Error("itemIndexCallback not set")

  for (var prop in customItems.value) {
    var qmlItemName = prop
    var qmlItemValue = customItems.value[qmlItemName]
    _doItemAction(qmlItemName, qmlItemValue, model, componentFactoryCallback, itemIndexCallback)
  }
}

function findIndex(model, typeName, typeCallback) {

	for (var i = 0; i < model.count; i++) {

		var itm = model.get(i)
		if (itm === null)
			continue
		if ((itm?.toString() || "").startsWith(typeName)) {
			if (typeCallback)
				if (typeCallback(model, itm, i) == -1)
					continue
				else
					return i
			return i
		}
	}
	return -1
}

function dumpInstanceProperties(instance) {
  if (!instance) {
    console.log("dumpInstanceProperties: no instance provided")
    return
  }
	try {
		Object.keys(instance).forEach(function(key) {
			try {
				var val = instance[key].toString()

				if (val.indexOf("function()") === 0)
					return

				console.log("instance." + key + ":", val)
			} catch (error) {
				console.log("instance." + key + ": <error reading value: " + error + ">");
			}
		})
	} catch (error) {
		console.log("instance." + key + ": <error reading value: " + error + ">");
	}

}

function modelAddRemoveItem(model, action, index, qmlFileName, componentFactoryCallback) {

	if (index === -1)
		return

  if (action === "-") {
    model.get(index).show = false // if removing just hide
    return
  }

  const COMPONENT_READY = 1

	//Qt.CreatComponent needs to be created in the same context that it
	// will be used in (so that it inherits stackPage, mbTools, toast etc)
  var componentFactory = componentFactoryCallback(qmlFileName, model, action, index)
	if (componentFactory == undefined)
		return // assume componentFactoryCallback has handled everything

  if (componentFactory.component.status === COMPONENT_READY) {
    var instance = componentFactory.component.createObject(
			componentFactory.parent,
			componentFactory.component.args) // incubateObject is non blocking
  } else {
    console.error("Failed to create component:", componentFactory.component.errorString());
    return
  }

  if (action === "*")
    model.get(index).show = false // if replacing just hide

  if (index === -2) {
    model.append(instance)
  } else {
    model.insert(index, instance)
  }
	return instance
}

function _doItemAction(qmlItemName, qmlItemValue, model, componentFactoryCallback, getItemIndexCallback) {

  var index = -1
  var action = undefined

  if (qmlItemValue?.length > 0)
    action = qmlItemValue[0]

  if (!qmlItemName.endsWith(".qml")) {
    qmlItemName += ".qml";
  }

  switch (action) {
    case "":
    case undefined:
      index = -2 // insert at end
      break
    case "^":
      index = 0 // insert at start
      break
    case "-": // remove @ item
    case "+": // insert @ item
    case "*": // replace @ item
      qmlItemValue = qmlItemValue.substring(1)
      index = getItemIndexCallback(model, qmlItemValue)
      break
    default:
      console.log("invalid operation: action='" + action + "', qmlItemName:'" + qmlItemName + "', qmlItemValue:'" + qmlItemValue + "'")
      return
  }

  if (index == -1) {
    console.log("index not found:" + qmlItemValue)
    return
  }

  modelAddRemoveItem(model, action, index, qmlItemName, componentFactoryCallback)

}
