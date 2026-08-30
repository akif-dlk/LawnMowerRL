function result = runBaselineSimulation(P, scenario, makePlots, show3D)
%RUNBASELINESIMULATION Klasik kapsama rotasını Simulink bitki modelinde çalıştırır.

arguments
    P struct = robotParameters()
    scenario struct = createGardenScenario(P,"demo")
    makePlots (1,1) logical = true
    show3D (1,1) logical = false
end

setupProject;
[pathXY,pathCells] = generateBoustrophedonBaseline(scenario);

P.sim.initialPose(1:2) = pathXY(1,:);
if size(pathXY,1) > 1
    P.sim.initialPose(3) = atan2(pathXY(2,2)-pathXY(1,2), pathXY(2,1)-pathXY(1,1));
end

[vCmdTs,wCmdTs,commandMeta] = pathToCommands(pathXY,P);
simStopTime = commandMeta.duration; %#ok<NASGU>
assignin("base","v_cmd_ts",vCmdTs);
assignin("base","w_cmd_ts",wCmdTs);
assignin("base","simStopTime",simStopTime);

modelPath = buildLawnMowerSimulinkModel(P,false);
load_system(modelPath);
cleanup = onCleanup(@() closeLoadedModel("LawnMowerPlant")); %#ok<NASGU>

simOut = sim("LawnMowerPlant", ...
    "StopTime", num2str(simStopTime,17), ...
    "ReturnWorkspaceOutputs", "on");

x = simOut.get("sim_x");
y = simOut.get("sim_y");
psi = simOut.get("sim_psi");
v = simOut.get("sim_v");
w = simOut.get("sim_w");
energy = simOut.get("sim_energy_Wh");
soc = simOut.get("sim_soc");

result.method = "Obstacle-aware boustrophedon";
result.scenario = scenario;
result.pathXY = pathXY;
result.pathCells = pathCells;
result.commandMeta = commandMeta;
result.sim.time = x.Time;
result.sim.x = x.Data;
result.sim.y = y.Data;
result.sim.psi = psi.Data;
result.sim.v = v.Data;
result.sim.w = w.Data;
result.sim.energyWh = energy.Data;
result.sim.soc = soc.Data;
result.metrics = computeCoverageMetrics(pathCells,scenario,P);
result.metrics.simulatedEnergy_Wh = energy.Data(end);
result.metrics.simulatedDuration_s = x.Time(end);

if makePlots
    plotBaselineResult(result,P);
end

if show3D
    result.viewer = animateLawnMower3D(result, scenario, P, "chase");
end

projectRoot = fileparts(fileparts(mfilename("fullpath")));
save(fullfile(projectRoot,"results","baseline_result.mat"),"result","P");
printMetrics(result.metrics,"Klasik serpantin");
end

function plotBaselineResult(result,P)
figure("Name","Klasik kapsama Simulink sonucu","Color","w");
tiledlayout(2,2,"TileSpacing","compact");

nexttile;
hold on;
img = imagesc([0 result.scenario.width],[0 result.scenario.height],double(result.scenario.obstacleMask));
img.HandleVisibility = "off";
set(gca,"YDir","normal");
colormap([0.82 0.93 0.78; 0.18 0.18 0.18]);
plot(result.pathXY(:,1),result.pathXY(:,2),"--","Color",[0.95 0.55 0.05]);
plot(result.sim.x,result.sim.y,"b-","LineWidth",1.1);
axis equal;
xlim([0 result.scenario.width]); ylim([0 result.scenario.height]);
grid on; xlabel("x [m]"); ylabel("y [m]");
title("Planlanan ve Simulink araç yolu");
legend("Plan","Araç","Location","best");

nexttile;
plot(result.sim.time,result.sim.v,"LineWidth",1.0); hold on;
plot(result.sim.time,result.sim.w,"LineWidth",1.0);
grid on; xlabel("t [s]"); ylabel("Komut/yanıt");
legend("v [m/s]","yaw rate [rad/s]"); title("Tahrik yanıtı");

nexttile;
plot(result.sim.time,result.sim.energyWh,"LineWidth",1.2);
grid on; xlabel("t [s]"); ylabel("Enerji [Wh]"); title("Tüketilen enerji");

nexttile;
plot(result.sim.time,100*result.sim.soc,"LineWidth",1.2);
grid on; xlabel("t [s]"); ylabel("SOC [%]"); ylim([0 101]); title("Batarya doluluk oranı");

sgtitle(sprintf("%s | biçme genişliği %.0f mm",P.meta.name,1000*P.cutting.width));
end

function printMetrics(M,label)
fprintf("\n%s metrikleri\n",label);
fprintf("  Kapsama:       %6.2f %%\n",100*M.coverageRatio);
fprintf("  Bindirme:      %6.2f %%\n",100*M.overlapRatio);
fprintf("  Yol:           %6.1f m\n",M.pathLength_m);
fprintf("  Dönüş olayı:   %6d\n",M.turnEvents);
fprintf("  Tahmini enerji:%6.1f Wh\n",M.estimatedEnergy_Wh);
if isfield(M,"simulatedEnergy_Wh")
    fprintf("  Simülasyon:    %6.1f Wh, %.1f s\n",M.simulatedEnergy_Wh,M.simulatedDuration_s);
end
end

function closeLoadedModel(modelName)
if bdIsLoaded(modelName)
    close_system(modelName,0);
end
end
