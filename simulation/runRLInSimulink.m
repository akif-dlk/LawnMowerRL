function result = runRLInSimulink(agent,P,scenario)
%RUNRLINSIMULINK DQN rotasını çıkarır ve aynı araç modelinde çalıştırır.

arguments
    agent
    P struct = robotParameters("quick")
    scenario struct = createGardenScenario(P,"demo")
end

result = evaluateCoverageAgent(agent,P,scenario,true);
if ~result.completed
    warning("Ajan hedef kapsama oranına ulaşmadı; oluşan kısmi yol yine de Simulink'te çalıştırılıyor.");
end

result.sim = simulatePathInSimulink(result.pathXY,P,true);
result.metrics.simulatedEnergy_Wh = result.sim.energy_Wh(end);
result.metrics.simulatedDuration_s = result.sim.time(end);

projectRoot = fileparts(fileparts(mfilename("fullpath")));
save(fullfile(projectRoot,"results","latest_rl_simulink_result.mat"),"result","P","-v7.3");
end

