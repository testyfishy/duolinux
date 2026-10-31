// Add a taskbar panel on the second screen (DP-1) so windows living there are
// visible and switchable, and new ones can be launched onto that screen.
var existing = null;
panels().forEach(function (p) {
    if (p.screen === 1) existing = p;
});

if (existing !== null) {
    print("panel already on screen 1: id=" + existing.id);
} else {
    var panel = new Panel("org.kde.panel");
    panel.screen = 1;
    panel.location = "bottom";
    panel.height = 40;
    panel.addWidget("org.kde.plasma.icontasks");
    panel.addWidget("org.kde.plasma.digitalclock");
    print("created panel on screen 1");
}
