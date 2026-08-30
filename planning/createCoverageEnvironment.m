function env = createCoverageEnvironment(P, scenario, validateNow)
%CREATECOVERAGEENVIRONMENT rlFunctionEnv tabanlı kapsama ortamını kurar.

arguments
    P struct = robotParameters()
    scenario struct = createGardenScenario(P,"demo")
    validateNow (1,1) logical = false
end

assert(exist("rlFunctionEnv","file") == 2, ...
    "Reinforcement Learning Toolbox bulunamadı.");

observationDimension = 2*scenario.rows*scenario.cols + 7;
observationInfo = rlNumericSpec([observationDimension 1]);
observationInfo.Name = "coverage_state";
observationInfo.Description = "cut map, obstacle map, position, heading, coverage";
observationInfo.LowerLimit = zeros(observationDimension,1);
observationInfo.UpperLimit = ones(observationDimension,1);

actionInfo = rlFiniteSetSpec(1:4);
actionInfo.Name = "grid_direction";
actionInfo.Description = "1=N, 2=E, 3=S, 4=W";

stepHandle = @(action,logged) stepCoverageEnv(action,logged);
resetHandle = @() resetCoverageEnv(P,scenario);
env = rlFunctionEnv(observationInfo,actionInfo,stepHandle,resetHandle);

if validateNow
    validateEnvironment(env);
    fprintf("RL ortamı doğrulandı: %d gözlem, %d ayrık aksiyon.\n", ...
        observationDimension,numel(actionInfo.Elements));
end
end
