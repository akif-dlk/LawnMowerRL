function result = runLiveSimulation(method, P, scenario, cameraMode)
%RUNLIVESIMULATION Simulink araç modelini koşturur ve 3D canlı ortamda izletir.
%
% Girdiler:
%   method     : "baseline" (klasik serpantin) veya "rl" (eğitilmiş DQN)
%   P          : Robot parametreleri (varsayılan: robotParameters("quick"))
%   scenario   : Bahçe senaryosu (varsayılan: createGardenScenario(P, "demo"))
%   cameraMode : "chase", "topdown", "orbit", "cockpit"

arguments
    method (1,1) string {mustBeMember(method, ["baseline", "rl"])} = "baseline"
    P struct = robotParameters("quick")
    scenario struct = createGardenScenario(P, "demo")
    cameraMode (1,1) string = "chase"
end

setupProject;

switch method
    case "baseline"
        fprintf("\n=== Klasik Kapsama Simulink 3D Simülasyonu ===\n");
        result = runBaselineSimulation(P, scenario, false);
        
    case "rl"
        fprintf("\n=== RL (DQN) Kapsama Simulink 3D Simülasyonu ===\n");
        % En son eğitilmiş ajanı yükle veya hızlıca eğit
        projectRoot = fileparts(fileparts(mfilename("fullpath")));
        resultsDir = fullfile(projectRoot, "results");
        agentFiles = dir(fullfile(resultsDir, "coverage_dqn_*.mat"));
        
        if ~isempty(agentFiles)
            [~, latestIdx] = max([agentFiles.datenum]);
            latestAgentFile = fullfile(resultsDir, agentFiles(latestIdx).name);
            fprintf("Kayıtlı DQN ajanı yüklendi: %s\n", agentFiles(latestIdx).name);
            data = load(latestAgentFile);
            agent = data.agent;
        else
            fprintf("Kayıtlı ajan bulunamadı, kısa hızlı eğitim yapılıyor...\n");
            [agent, ~] = trainCoverageDQN(P, scenario);
        end
        
        result = runRLInSimulink(agent, P, scenario);
end

fprintf("\nSimulink simülasyonu tamamlandı. 3D Canlı İzleyici başlatılıyor...\n");
viewer = animateLawnMower3D(result, scenario, P, cameraMode);
result.viewer = viewer;

end
