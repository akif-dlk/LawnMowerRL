function [nextObservation, reward, isDone, logged] = stepCoverageEnv(action, logged)
%STEPCOVERAGEENV Dört komşulu kapsama MDP geçiş ve ödül fonksiyonu.
% Aksiyonlar: 1=N, 2=E, 3=S, 4=W.

if iscell(action)
    action = action{1};
end
action = double(action);
validateattributes(action,{'numeric'},{'scalar','integer','>=',1,'<=',4});

P = logged.P;
scenario = logged.Scenario;
directions = [1 0; 0 1; -1 0; 0 -1];
candidate = logged.Cell + directions(action,:);

previousPotential = nearestUncutDistance(logged.Cell,logged.CutMask,scenario);
quarterTurns = directionChange(logged.Heading,action);
reward = P.reward.step + P.reward.turnPerQuarter*quarterTurns;

valid = candidate(1) >= 1 && candidate(1) <= scenario.rows && ...
    candidate(2) >= 1 && candidate(2) <= scenario.cols && ...
    scenario.freeMask(candidate(1),candidate(2));

if valid
    logged.Cell = candidate;
    logged.ConsecutiveInvalid = 0;
    if ~logged.CutMask(candidate(1),candidate(2))
        logged.CutMask(candidate(1),candidate(2)) = true;
        reward = reward + P.reward.newCell;
    else
        reward = reward + P.reward.revisit;
    end
else
    logged.InvalidMoveCount = logged.InvalidMoveCount + 1;
    logged.ConsecutiveInvalid = logged.ConsecutiveInvalid + 1;
    reward = reward + P.reward.invalidMove;
end

logged.Heading = action;
logged.StepCount = logged.StepCount + 1;
logged.CoverageRatio = nnz(logged.CutMask & scenario.freeMask) / scenario.freeCellCount;

currentPotential = nearestUncutDistance(logged.Cell,logged.CutMask,scenario);
reward = reward + P.reward.progressPotential*(previousPotential-currentPotential);

[stepEnergy,stepTime] = transitionCost(valid,quarterTurns,P,scenario);
logged.EnergyWh = logged.EnergyWh + stepEnergy;
logged.ElapsedTime = logged.ElapsedTime + stepTime;
reward = reward + P.reward.energyPerWh*stepEnergy;

complete = logged.CoverageRatio >= P.coverage.targetRatio;
timedOut = logged.StepCount >= P.rl.maxSteps;
stuck = logged.ConsecutiveInvalid >= 20;
isDone = complete || timedOut || stuck;

if complete
    reward = reward + P.reward.completion;
elseif stuck
    reward = reward + 2*P.reward.invalidMove;
end

nextObservation = encodeCoverageObservation(logged);
end

function distance = nearestUncutDistance(cell,cutMask,scenario)
[rows,cols] = find(scenario.freeMask & ~cutMask);
if isempty(rows)
    distance = 0;
else
    distance = min(abs(rows-cell(1)) + abs(cols-cell(2)));
    distance = distance / (scenario.rows + scenario.cols);
end
end

function quarterTurns = directionChange(previous,current)
raw = abs(previous-current);
quarterTurns = min(raw,4-raw);
end

function [energyWh,elapsedTime] = transitionCost(valid,quarterTurns,P,scenario)
basePower = P.energy.idlePower + P.cutting.bladePower;
turnTime = quarterTurns*(pi/2)/P.drive.maxYawRate;
if valid
    driveTime = scenario.cellSize/P.drive.nominalMowingSpeed;
else
    driveTime = P.sim.sampleTime;
end
drivePower = basePower + P.energy.linearCoeff*P.drive.nominalMowingSpeed;
turnPower = basePower + P.energy.yawCoeff*P.drive.maxYawRate;
energyWh = (drivePower*driveTime + turnPower*turnTime)/3600;
elapsedTime = driveTime + turnTime;
end
