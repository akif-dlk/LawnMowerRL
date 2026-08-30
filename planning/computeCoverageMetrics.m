function metrics = computeCoverageMetrics(pathCells, scenario, P)
%COMPUTECOVERAGEMETRICS Bir hücre rotasının dış başarı metriklerini hesaplar.

arguments
    pathCells (:,2) double
    scenario struct
    P struct = robotParameters()
end

valid = pathCells(:,1) >= 1 & pathCells(:,1) <= scenario.rows & ...
    pathCells(:,2) >= 1 & pathCells(:,2) <= scenario.cols;
pathCells = pathCells(valid,:);
indices = sub2ind([scenario.rows scenario.cols], pathCells(:,1), pathCells(:,2));
freeVisits = scenario.freeMask(indices);
indices = indices(freeVisits);

uniqueCut = unique(indices, "stable");
moveDelta = diff(pathCells,1,1);
manhattan = sum(abs(moveDelta),2);
adjacentMove = manhattan == 1;
distance = nnz(adjacentMove) * scenario.cellSize;

directions = zeros(size(moveDelta,1),1);
directions(moveDelta(:,1) == 1 & moveDelta(:,2) == 0) = 1;  % N
directions(moveDelta(:,1) == 0 & moveDelta(:,2) == 1) = 2;  % E
directions(moveDelta(:,1) == -1 & moveDelta(:,2) == 0) = 3; % S
directions(moveDelta(:,1) == 0 & moveDelta(:,2) == -1) = 4; % W
directions = directions(directions > 0);

if numel(directions) > 1
    rawTurn = abs(diff(directions));
    quarterTurns = sum(min(rawTurn, 4-rawTurn));
    turnEvents = nnz(rawTurn > 0);
else
    quarterTurns = 0;
    turnEvents = 0;
end

driveTime = distance / P.drive.nominalMowingSpeed;
turnTime = quarterTurns * (pi/2) / P.drive.maxYawRate;
basePower = P.energy.idlePower + P.cutting.bladePower;
drivePower = basePower + P.energy.linearCoeff * P.drive.nominalMowingSpeed;
turnPower = basePower + P.energy.yawCoeff * P.drive.maxYawRate;
energyWh = (drivePower*driveTime + turnPower*turnTime) / 3600;

metrics.coverageRatio = numel(uniqueCut) / scenario.freeCellCount;
metrics.coveredArea_m2 = numel(uniqueCut) * scenario.cellSize^2;
metrics.revisitCount = max(0, numel(indices) - numel(uniqueCut));
metrics.overlapRatio = metrics.revisitCount / max(1,numel(indices));
metrics.pathLength_m = distance;
metrics.turnEvents = turnEvents;
metrics.quarterTurns = quarterTurns;
metrics.estimatedDuration_s = driveTime + turnTime;
metrics.estimatedEnergy_Wh = energyWh;
metrics.energyPerArea_Wh_m2 = energyWh / max(metrics.coveredArea_m2, eps);
end

