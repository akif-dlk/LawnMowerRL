function comparison = compareCoverageMethods(rlResult,P)
%COMPARECOVERAGEMETHODS DQN ve klasik serpantin dış metriklerini karşılaştırır.

arguments
    rlResult struct
    P struct = robotParameters("quick")
end

scenario = rlResult.scenario;
[~,baselineCells] = generateBoustrophedonBaseline(scenario);
baseline = computeCoverageMetrics(baselineCells,scenario,P);
rl = rlResult.metrics;

method = ["Klasik serpantin"; "DQN"];
coverage_pct = 100*[baseline.coverageRatio; rl.coverageRatio];
overlap_pct = 100*[baseline.overlapRatio; rl.overlapRatio];
path_m = [baseline.pathLength_m; rl.pathLength_m];
turns = [baseline.turnEvents; rl.turnEvents];
energy_Wh = [baseline.estimatedEnergy_Wh; rl.estimatedEnergy_Wh];
duration_s = [baseline.estimatedDuration_s; rl.estimatedDuration_s];

comparison = table(method,coverage_pct,overlap_pct,path_m,turns,energy_Wh,duration_s);
disp(comparison);

figure("Name","Kapsama yöntemleri karşılaştırması","Color","w");
tiledlayout(2,2,"TileSpacing","compact");
nexttile; bar(categorical(method),coverage_pct); ylabel("Kapsama [%]"); grid on;
nexttile; bar(categorical(method),overlap_pct); ylabel("Bindirme [%]"); grid on;
nexttile; bar(categorical(method),energy_Wh); ylabel("Tahmini enerji [Wh]"); grid on;
nexttile; bar(categorical(method),turns); ylabel("Dönüş olayı"); grid on;
sgtitle("Aynı bahçede dış metrik karşılaştırması");
end

