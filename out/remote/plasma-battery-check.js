// Report and fix the battery applet's display settings.
var panel = null;
panels().forEach(function (p) { if (p.screen === 0) panel = p; });
if (panel === null && panels().length) panel = panels()[0];

var battery = null;
panel.widgets().forEach(function (w) {
    if (w.type === "org.kde.plasma.battery") battery = w;
});

if (battery === null) {
    print("battery applet missing");
} else {
    battery.currentConfigGroup = ["General"];
    print("before: showPercentage=" + battery.readConfig("showPercentage"));
    battery.writeConfig("showPercentage", true);
    battery.writeConfig("showTimeRemaining", false);
    print("after: showPercentage=" + battery.readConfig("showPercentage"));
    print("height=" + panel.height + " id=" + battery.id);
}
