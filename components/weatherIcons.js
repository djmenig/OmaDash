// Nerd-Font weather glyph map, copied verbatim from the built-in
// omarchy weather panel (plugins/panels/weather/Model.js) so OmaDash's
// weather slot uses the exact same icons as the rest of the shell.
function iconForOpenMeteoCode(code, night) {
  var c = parseInt(String(code || "0"), 10)
  if (c === 0) return iconForCode(113, night)
  if (c === 1 || c === 2) return iconForCode(116, night)
  if (c === 3) return iconForCode(119, night)
  if (c === 45 || c === 48) return iconForCode(143, night)
  if (c === 51 || c === 53 || c === 55 || c === 56 || c === 57 || c === 61) return iconForCode(266, night)
  if (c === 63 || c === 65 || c === 66 || c === 67 || c === 80 || c === 81 || c === 82) return iconForCode(308, night)
  if (c === 71 || c === 73 || c === 75 || c === 77 || c === 85 || c === 86) return iconForCode(338, night)
  if (c === 95 || c === 96 || c === 99) return iconForCode(389, night)
  return iconForCode(119, night)
}

function iconForCode(code, night) {
  var c = parseInt(String(code || "0"), 10)
  switch (c) {
    case 113: return night ? "" : ""
    case 116: return night ? "" : ""
    case 119: case 122: return ""
    case 143: case 248: case 260: return night ? "\ue346" : "\ue313"
    case 176: case 263: case 353: return night ? "" : ""
    case 179: case 227: case 230: case 323: case 326: case 368: return night ? "" : ""
    case 182: case 185: case 281: case 284: case 311: case 314:
    case 317: case 320: case 350: case 362: case 365: case 374: case 377: return ""
    case 200: case 386: case 389: case 392: case 395: return ""
    case 266: case 293: case 296: case 299: case 302: case 305: case 308: case 356: case 359: return ""
    case 329: case 332: case 335: case 338: case 371: return ""
    default: return ""
  }
}
