// Replace the broken stock battery widget (Debian does not ship that applet)
// with org.duo.battery. Tries the documented scripting calls in order because
// removeWidget is not available in every Plasma 6 minor release.
var panel = null;
panels().forEach(function (p) { if (p.screen === 0) panel = p; });
if (panel === null && panels().length) panel = panels()[0];
if (panel === null) {
    print("no panel");
} else {
    var broken = null;
    panel.widgets().forEach(function (w) {
        if (w.type === "org.kde.plasma.battery") broken = w;
    });
    if (broken !== null) {
        var removed = false;
        if (typeof broken.remove === "function") {
            broken.remove();
            removed = true;
        } else if (typeof panel.removeWidget === "function") {
            panel.removeWidget(broken);
            removed = true;
        } else if (typeof broken.deleteLater === "function") {
            broken.deleteLater();
            removed = true;
        }
        print("broken widget removed: " + removed);
    } else {
        print("no broken battery widget present");
    }

    var have = null;
    panel.widgets().forEach(function (w) {
        if (w.type === "org.duo.battery") have = w;
    });
    if (have === null) {
        panel.addWidget("org.duo.battery");
        print("added org.duo.battery");
    } else {
        print("org.duo.battery already present");
    }
}
