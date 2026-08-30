function fig = showGardenScenario(scenario, P, pathXY)
%SHOWGARDENSCENARIO Bahçe, engeller ve isteğe bağlı rotayı çizer.

arguments
    scenario struct
    P struct = robotParameters()
    pathXY double = zeros(0,2)
end

fig = figure("Name", "Bahçe senaryosu", "Color", "w");
ax = axes(fig);
hold(ax, "on");

imagesc(ax, [0 scenario.width], [0 scenario.height], double(scenario.obstacleMask));
set(ax, "YDir", "normal");
colormap(ax, [0.78 0.92 0.72; 0.22 0.24 0.22]);

startXY = cellsToWorld(scenario.startCell, scenario);
plot(ax, startXY(1), startXY(2), "o", "MarkerFaceColor", [0.1 0.45 0.95], ...
    "MarkerEdgeColor", "w", "MarkerSize", 8, "DisplayName", "Başlangıç");

if ~isempty(pathXY)
    plot(ax, pathXY(:,1), pathXY(:,2), "-", "Color", [0.95 0.55 0.05], ...
        "LineWidth", 1.1, "DisplayName", "Rota");
end

axis(ax, "equal");
xlim(ax, [0 scenario.width]);
ylim(ax, [0 scenario.height]);
grid(ax, "on");
xlabel(ax, "x [m]");
ylabel(ax, "y [m]");
title(ax, sprintf("%s | %.1f m x %.1f m | %.0f mm biçme", ...
    scenario.name, scenario.width, scenario.height, 1000*P.cutting.width));
legend(ax, "Location", "best");
end
