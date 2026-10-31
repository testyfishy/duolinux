// Hide the system tray's battery item; the panel's own applet (with the
// percentage) is the one to keep.
var panel = null;
panels().forEach(function (p) { if (p.screen === 0) panel = p; });
if (panel === null && panels().length) panel = panels()[0];

var tray = null;
panel.widgets().forEach(function (w) {
    if (w.type === "org.kde.plasma.systemtray") tray = w;
});

if (tray === null) {
    print("no system tray found");
} else {
    tray.currentConfigGroup = ["General"];
    var hidden = tray.readConfig("hiddenItems") || "";
    var items = hidden.split(",").filter(function (i) { return i.length > 0; });
    if (items.indexOf("org.kde.plasma.battery") === -1) {
        items.push("org.kde.plasma.battery");
    }
    tray.writeConfig("hiddenItems", items.join(","));
    print("hiddenItems now: " + tray.readConfig("hiddenItems"));
}
