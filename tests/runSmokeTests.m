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

% 3D Görselleştirici duman testi
try
    viewer = LawnMower3DViewer(scenario, P, "chase");
    viewer.updatePose(0.5, 0.5, 0.1, 0.4, 0.0, 1.2, 0.99, 1.0);
    viewer.setCameraMode("topdown");
    viewer.setCameraMode("orbit");
    viewer.setCameraMode("cockpit");
    if isvalid(viewer.Figure)
        close(viewer.Figure);
    end
    results.viewer3DPassed = true;
catch ME
    warning("3D Görselleştirici testi uyarısı: %s", ME.message);
    results.viewer3DPassed = false;
end

results.passed = true;
results.baselineMetrics = M;
results.testedAt = datetime("now");
fprintf("Smoke testleri geçti. Klasik kapsama: %.2f %%\n",100*M.coverageRatio);
end

