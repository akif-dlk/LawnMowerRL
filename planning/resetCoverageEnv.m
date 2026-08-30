function [initialObservation, logged] = resetCoverageEnv(P, scenario)
%RESETCOVERAGEENV RL kapsama ortamını başlangıç durumuna getirir.

logged.P = P;
logged.Scenario = scenario;
logged.Cell = scenario.startCell;
logged.Heading = scenario.startHeading;
logged.CutMask = false(scenario.rows,scenario.cols);
logged.CutMask(logged.Cell(1),logged.Cell(2)) = true;
logged.CoverageRatio = 1/scenario.freeCellCount;
logged.StepCount = 0;
logged.InvalidMoveCount = 0;
logged.ConsecutiveInvalid = 0;
logged.EnergyWh = 0;
logged.ElapsedTime = 0;
initialObservation = encodeCoverageObservation(logged);
end
