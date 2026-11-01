

function _linearize(c) {
  // c is 0..1 sRGB channel
  return (c <= 0.04045) ? (c / 12.92) : Math.pow((c + 0.055) / 1.055, 2.4)
}

function _relativeLuminance(col) {
  var r = _linearize(col.r)
  var g = _linearize(col.g)
  var b = _linearize(col.b)
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

function isLightColor(col) {
  return _relativeLuminance(col) > 0.5
}

function isDarkColor(col) {
  return !isLightColor(col)
}