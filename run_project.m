%% LawnMowerRL başlangıç demosu
% Windows'ta MATLAB Current Folder bu klasör olacak şekilde çalıştırın.

projectRoot = fileparts(mfilename("fullpath"));
cd(projectRoot);
setupProject;

P = robotParameters("quick");
checkRequirements;

fprintf("\n1/4 Mekanik konsept çiziliyor...\n");
showMechanicalConcept(P);

fprintf("2/4 Bahçe senaryosu hazırlanıyor...\n");
scenario = createGardenScenario(P, "demo");
showGardenScenario(scenario, P);

fprintf("3/4 Simulink modeli ve klasik kapsama deneyi çalıştırılıyor...\n");
baselineResult = runBaselineSimulation(P, scenario, true); %#ok<NASGU>

fprintf("4/4 RL ortamı hazırlanıyor...\n");
if exist("rlFunctionEnv", "file") == 2
    env = createCoverageEnvironment(P, scenario, true); %#ok<NASGU>
    assignin("base", "coverageEnv", env);
    fprintf("RL ortamı 'coverageEnv' adıyla Workspace'e aktarıldı.\n");
else
    warning("Reinforcement Learning Toolbox bulunamadı. Klasik Simulink demosu tamamlandı; RL ortamı atlandı.");
end

fprintf("\nBaşlangıç tamamlandı.\n");
fprintf(" - 3D Canlı Simülasyonu izlemek için: run_3d_demo\n");
fprintf(" - RL Ajanını eğitmek için:           [agent,stats] = trainCoverageDQN(P);\n");
fprintf(" - Canlı simülasyonu başlatmak için:  runLiveSimulation('baseline', P, scenario);\n");

