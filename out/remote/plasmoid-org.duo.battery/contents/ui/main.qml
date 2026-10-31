// Battery indicator for the handheld's top panel.
//
// Debian's Plasma packaging does not ship org.kde.plasma.battery, so there is
// no stock panel battery monitor. This reads sysfs directly; QML file reads
// need QML_XHR_ALLOW_FILE_READ=1, which duo-session exports.
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string base: "file:///sys/class/power_supply/battery/"
    property int capacity: -1
    property string status: ""

    function readValue(name, callback) {
        const request = new XMLHttpRequest();
        request.open("GET", root.base + name, false);
        try {
            request.send(null);
            callback(request.responseText.trim());
        } catch (error) {
            callback("");
        }
    }

    function refresh() {
        root.readValue("capacity", function (value) {
            const parsed = parseInt(value, 10);
            root.capacity = isNaN(parsed) ? -1 : parsed;
        });
        root.readValue("status", function (value) {
            root.status = value;
        });
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    compactRepresentation: Item {
        implicitWidth: Math.max(46, label.implicitWidth + 10)
        implicitHeight: Kirigami.Units.iconSizes.smallMedium

        Text {
            id: label
            anchors.centerIn: parent
            text: root.capacity >= 0 ? root.capacity + "%" : "..."
            color: "#ffffff"
            font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.7)
        }
    }

    toolTipMainText: "Battery"
    toolTipSubText: (root.capacity >= 0 ? root.capacity + "%" : "Unknown") +
                    (root.status ? " - " + root.status : "")
}
