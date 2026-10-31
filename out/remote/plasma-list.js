var lines = [];
panels().forEach(function (p) {
    lines.push("panel " + p.id + " screen=" + p.screen + " h=" + p.height +
               " widgets=" + p.widgets().map(function (w) { return w.type; }).join(","));
});
print(lines.join(" | "));
