function fig = showMechanicalConcept(P)
%SHOWMECHANICALCONCEPT Robotun üstten kavramsal mekanik yerleşimini çizer.

arguments
    P struct = robotParameters()
end

L = P.body.length;
W = P.body.width;
wb = P.body.wheelbase;
tw = P.body.trackWidth;
rw = P.wheel.radius;
ww = P.wheel.width;

fig = figure("Name", "LMR-680 mekanik konsept", "Color", "w");
ax = axes(fig);
hold(ax, "on");
axis(ax, "equal");

% Gövde.
rectangle(ax, "Position", [-L/2 -W/2 L W], "Curvature", 0.25, ...
    "FaceColor", [0.83 0.12 0.10], "EdgeColor", [0.35 0.04 0.04], "LineWidth", 2);

% Kesici diskler; şemada görünür olması için gövde üstünde yarı saydam çizilir.
discR = 0.105;
theta = linspace(0, 2*pi, 100);
for cy = [-0.095 0.095]
    fill(ax, -0.03 + discR*cos(theta), cy + discR*sin(theta), ...
        [0.95 0.72 0.18], "FaceAlpha", 0.65, "EdgeColor", [0.65 0.38 0.05]);
end

% Dört tahrik tekeri.
for x = [-wb/2 wb/2]
    for y = [-tw/2 tw/2]
        rectangle(ax, "Position", [x-rw, y-ww/2, 2*rw, ww], "Curvature", 0.2, ...
            "FaceColor", [0.08 0.08 0.09], "EdgeColor", [0 0 0]);
    end
end

% Ön sensör ve RTK anteni.
plot(ax, L/2-0.035, 0, "^", "MarkerSize", 12, "MarkerFaceColor", [0.2 0.75 0.95], ...
    "MarkerEdgeColor", "w");
plot(ax, 0.04, 0, "o", "MarkerSize", 11, "MarkerFaceColor", [0.94 0.94 0.94], ...
    "MarkerEdgeColor", [0.15 0.15 0.15]);

text(ax, 0, 0.165, "Yüzer çift disk tabla", "HorizontalAlignment", "center", ...
    "Color", "w", "FontWeight", "bold");
text(ax, L/2+0.02, 0, "Ön", "HorizontalAlignment", "left", "FontWeight", "bold");
text(ax, 0.04, -0.035, "RTK", "HorizontalAlignment", "center", "FontSize", 8);

xlim(ax, [-L/2-0.16 L/2+0.16]);
ylim(ax, [-W/2-0.14 W/2+0.14]);
grid(ax, "on");
xlabel(ax, "Boyuna eksen [m]");
ylabel(ax, "Enine eksen [m]");
title(ax, sprintf("%s — %.0f x %.0f x %.0f mm, 4WD iki taraf kontrollü", ...
    P.meta.name, 1000*L, 1000*W, 1000*P.body.height));
end
