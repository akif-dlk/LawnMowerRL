function results = runSmokeTests(buildSimulinkModel)
%RUNSMOKETESTS Eğitim yapmadan proje çekirdeğini kontrol eder.

arguments
    buildSimulinkModel (1,1) logical = false
end

setupProject;
P = robotParameters("quick");
scenario = createGardenScenario(P,"demo");

assert(P.body.length > P.body.width);
assert(P.cutting.width <= P.body.width);
assert(~scenario.obstacleMask(scenario.startCell(1),scenario.startCell(2)));

[pathXY,pathCells] = generateBoustrophedonBaseline(scenario);
assert(size(pathXY,1) == size(pathCells,1));
delta = abs(diff(pathCells,1,1));
assert(all(sum(delta,2) == 1),"Klasik rotada komşu olmayan sıçrama var.");
idx = sub2ind([scenario.rows scenario.cols],pathCells(:,1),pathCells(:,2));
assert(all(scenario.freeMask(idx)),"Klasik rota engel hücresinden geçiyor.");

M = computeCoverageMetrics(pathCells,scenario,P);
assert(M.coverageRatio > 0.999,"Klasik rota tüm erişilebilir hücreleri kapsamıyor.");

[observation,logged] = resetCoverageEnv(P,scenario);
assert(numel(observation) == 2*scenario.rows*scenario.cols+7);
[nextObservation,reward,isDone,logged] = stepCoverageEnv(2,logged); %#ok<ASGLU>
assert(numel(nextObservation) == numel(observation));
assert(isfinite(reward));

[vTs,wTs,commandMeta] = pathToCommands(pathXY(1:min(40,end),:),P); %#ok<ASGLU>
assert(commandMeta.duration > 0);

if exist("rlFunctionEnv","file") == 2
    createCoverageEnvironment(P,scenario,true);
end

if buildSimulinkModel
    buildLawnMowerSimulinkModel(P,false);
end

results.passed = true;
results.baselineMetrics = M;
results.testedAt = datetime("now");
fprintf("Smoke testleri geçti. Klasik kapsama: %.2f %%\n",100*M.coverageRatio);
end

