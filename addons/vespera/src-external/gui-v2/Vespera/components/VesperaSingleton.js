.pragma library

var _cache = []; // This array lives for the entire application life cycle
var _customPageModel
var _isReload = true;

function getIsReload() { return _isReload }
function setIsReload(value) { _isReload = value }
function clearCache() { _cache = [] }

//We *must* create the VesperaCustomPageModel page in here and
// *not* in a qml file to ensure the obj lifetime outlives the qml page
function createCustomPageModel(parent) {
	if (!_customPageModel) {
		var pageUrl = "qrc:/Vespera/components/CustomPageModel.qml"
		_customPageModel = createPage(pageUrl, parent)

		_cache.push({key: pageUrl, value: _customPageModel})
		return true
	}
	return false
}

function toggleCustomPage(pageName, toggleCustomPage) {
	console.log("VesperaSingleton: in:",_customPageModel)
	 if (_customPageModel) _customPageModel.toggleCustomPage(pageName, toggleCustomPage)
}

function customPageModelExists() { return _customPageModel != undefined }

function findIndexInCache(key) {
	for (var i = 0; i < _cache.length; i++)
		if (_cache[i].key === key)
			return i
}

function createPage(url, parent, args) {
	//console.debug("VesperaSingleton: createPage: " + url)
	var component = Qt.createComponent(url);

	if (component.status === 1) {
			// 2. Instantiate the object.
			// Pass 'parentItem' so it is visible in the UI hierarchy, or 'root' for context.
			var page = component.createObject(parent, args);
			if (page !== null) return page
			console.error("VesperaSingleton: Error instantiating the Motorhome object:");
	} else if (component.status === 3) {
			console.error("VesperaSingleton: Error loading component:", component.errorString());
	}
}