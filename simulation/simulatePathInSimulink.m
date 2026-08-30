function simResult = simulatePathInSimulink(pathXY,P,makePlots)
%SIMULATEPATHINSIMULINK Herhangi bir kapsama yolunu araç modelinde çalıştırır.

arguments
    pathXY (:,2) double
    P struct = robotParameters()
    makePlots (1,1) logical = true
end

assert(size(pathXY,1) >= 2,"Simülasyon yolu en az iki nokta içermelidir.");
P.sim.initialPose(1:2) = pathXY(1,:);
P.sim.initialPose(3) = atan2(pathXY(2,2)-pathXY(1,2),pathXY(2,1)-pathXY(1,1));

[vCmdTs,wCmdTs,commandMeta] = pathToCommands(pathXY,P);
simStopTime = commandMeta.duration;
assignin("base","v_cmd_ts",vCmdTs);
assignin("base","w_cmd_ts",wCmdTs);
assignin("base","simStopTime",simStopTime);

modelPath = buildLawnMowerSimulinkModel(P,false);
load_system(modelPath);
cleanup = onCleanup(@() closeLoadedModel("LawnMowerPlant")); %#ok<NASGU>
out = sim("LawnMowerPlant","StopTime",num2str(simStopTime,17), ...
    "ReturnWorkspaceOutputs","on");

names = ["x","y","psi","v","w","energy_Wh","soc"];
workspaceNames = ["sim_x","sim_y","sim_psi","sim_v","sim_w","sim_energy_Wh","sim_soc"];
for k = 1:numel(names)
    value = out.get(workspaceNames(k));
    simResult.(names(k)) = value.Data;
    if k == 1
        simResult.time = value.Time;
    end
end
simResult.commandMeta = commandMeta;

if makePlots
    figure("Name","Kapsama yolu Simulink doğrulaması","Color","w");
    tiledlayout(1,2,"TileSpacing","compact");
    nexttile; hold on;
    plot(pathXY(:,1),pathXY(:,2),"--","Color",[0.95 0.55 0.05],"DisplayName","Plan");
    plot(simResult.x,simResult.y,"b-","LineWidth",1.2,"DisplayName","Simulink araç");
    axis equal; grid on; xlabel("x [m]"); ylabel("y [m]"); legend;
    title("Yol takibi");
    nexttile;
    yyaxis left; plot(simResult.time,simResult.energy_Wh,"LineWidth",1.2); ylabel("Enerji [Wh]");
    yyaxis right; plot(simResult.time,100*simResult.soc,"LineWidth",1.2); ylabel("SOC [%]");
    grid on; xlabel("t [s]"); title("Enerji modeli");
end
end

function closeLoadedModel(modelName)
if bdIsLoaded(modelName)
    close_system(modelName,0);
end
end

