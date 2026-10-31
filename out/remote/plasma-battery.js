// Add the battery monitor to the top panel and make it show a percentage.
// Plasma only puts one there by default on laptops; this device is a handheld
// with a battery, so it belongs next to the clock.
var target = null;
panels().forEach(function (p) {
    if (p.screen === 0) target = p;
});
if (target === null && panels().length > 0) target = panels()[0];

if (target === null) {
    print("no panel found");
} else {
    var existing = null;
    target.widgets().forEach(function (w) {
        if (w.type === "org.kde.plasma.battery") existing = w;
    });
    var battery = existing;
    if (battery === null) {
        battery = target.addWidget("org.kde.plasma.battery");
        print("battery widget added to panel " + target.id);
    } else {
        print("battery widget already present");
    }
    // Show the numeric percentage next to the icon.
    battery.currentConfigGroup = ["General"];
    battery.writeConfig("showPercentage", true);
    battery.writeConfig("showTimeRemaining", false);
    print("percentage enabled");
}
