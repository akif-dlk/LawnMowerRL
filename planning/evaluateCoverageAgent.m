function result = evaluateCoverageAgent(agent,P,scenario,makePlot)
%EVALUATECOVERAGEAGENT Eğitilmiş ajanı keşifsiz çalıştırır ve metrik çıkarır.

arguments
    agent
    P struct = robotParameters("quick")
    scenario struct = createGardenScenario(P,"demo")
    makePlot (1,1) logical = true
end

env = createCoverageEnvironment(P,scenario,false);
agent.UseExplorationPolicy = false;
[observation,logged] = reset(env);
pathCells = logged.Cell;
episodeReward = 0;

for k = 1:P.rl.maxSteps
    action = getAction(agent,observation);
    if iscell(action)
        action = action{1};
    end
    [observation,reward,isDone,logged] = step(env,action);
    episodeReward = episodeReward + reward;
    pathCells(end+1,:) = logged.Cell; %#ok<AGROW>
    if isDone
        break;
    end
end

result.method = "DQN coverage";
result.scenario = scenario;
result.pathCells = pathCells;
result.pathXY = cellsToWorld(pathCells,scenario);
result.episodeReward = episodeReward;
result.steps = k;
result.completed = logged.CoverageRatio >= P.coverage.targetRatio;
result.invalidMoveCount = logged.InvalidMoveCount;
result.environmentEnergy_Wh = logged.EnergyWh;
result.environmentDuration_s = logged.ElapsedTime;
result.metrics = computeCoverageMetrics(pathCells,scenario,P);

if makePlot
    showGardenScenario(scenario,P,result.pathXY);
    title(sprintf("DQN rota | kapsama %.1f%% | ödül %.1f", ...
        100*result.metrics.coverageRatio,result.episodeReward));
end

projectRoot = fileparts(fileparts(mfilename("fullpath")));
save(fullfile(projectRoot,"results","latest_rl_evaluation.mat"),"result","P");
end

