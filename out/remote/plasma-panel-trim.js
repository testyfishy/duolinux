// Make room on the panel: the pager (workspace switcher) and show-desktop are
// pointless on a handheld, and they pushed the battery applet off the right
// edge where it could not be seen.
var panel = null;
panels().forEach(function (p) { if (p.screen === 0) panel = p; });
if (panel === null && panels().length) panel = panels()[0];

if (panel === null) {
    print("no panel");
} else {
    var doomed = [];
    panel.widgets().forEach(function (w) {
        if (w.type === "org.kde.plasma.pager" ||
            w.type === "org.kde.plasma.showdesktop") {
            doomed.push(w);
        }
    });
    doomed.forEach(function (w) {
        try {
            w.remove();
            print("removed " + w.type);
        } catch (error) {
            print("cannot remove " + w.type + ": " + error);
        }
    });
    print("remaining: " + panel.widgets().map(function (w) { return w.type; }).join(","));
}
