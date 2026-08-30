function [agent,trainingStats] = trainCoverageDQN(P,scenario)
%TRAINCOVERAGEDQN Kapsama rotası için Double-DQN ajanı eğitir.

arguments
    P struct = robotParameters("quick")
    scenario struct = createGardenScenario(P,"demo")
end

setupProject;
rng(P.rl.randomSeed,"twister");
env = createCoverageEnvironment(P,scenario,true);
observationInfo = getObservationInfo(env);
actionInfo = getActionInfo(env);

% Varsayılan vektör Q-ağını oluşturup eğitim seçeneklerini açıkça ayarla.
agent = rlDQNAgent(observationInfo,actionInfo);
agent.AgentOptions.DiscountFactor = P.rl.discountFactor;
agent.AgentOptions.UseDoubleDQN = true;
agent.AgentOptions.TargetUpdateFrequency = P.rl.targetUpdateFrequency;
agent.AgentOptions.TargetSmoothFactor = 1.0;
agent.AgentOptions.ExperienceBufferLength = P.rl.experienceBufferLength;
agent.AgentOptions.MiniBatchSize = P.rl.miniBatchSize;
agent.AgentOptions.LearningFrequency = 1;
agent.AgentOptions.CriticOptimizerOptions.LearnRate = P.rl.learningRate;
agent.AgentOptions.CriticOptimizerOptions.GradientThreshold = 1;
agent.AgentOptions.EpsilonGreedyExploration.Epsilon = P.rl.epsilon;
agent.AgentOptions.EpsilonGreedyExploration.EpsilonMin = P.rl.epsilonMin;
agent.AgentOptions.EpsilonGreedyExploration.EpsilonDecay = P.rl.epsilonDecay;

projectRoot = fileparts(fileparts(mfilename("fullpath")));
agentFolder = fullfile(projectRoot,"results","saved_agents_" + P.rl.profile);
if ~isfolder(agentFolder)
    mkdir(agentFolder);
end

useParallel = P.rl.useParallel && license("test","Distrib_Computing_Toolbox");
if P.rl.useParallel && ~useParallel
    warning("Parallel Computing Toolbox lisansı bulunamadı; eğitim seri çalışacak.");
end

trainingOptions = rlTrainingOptions( ...
    MaxEpisodes=P.rl.maxEpisodes, ...
    MaxStepsPerEpisode=P.rl.maxSteps, ...
    ScoreAveragingWindowLength=P.rl.scoreWindow, ...
    StopTrainingCriteria="AverageReward", ...
    StopTrainingValue=P.rl.stopAverageReward, ...
    SaveAgentCriteria="EpisodeReward", ...
    SaveAgentValue=P.rl.stopAverageReward, ...
    SaveAgentDirectory=agentFolder, ...
    Verbose=true, ...
    Plots="training-progress", ...
    UseParallel=useParallel);

fprintf("DQN eğitimi başlıyor: %s profil, en fazla %d bölüm.\n", ...
    P.rl.profile,P.rl.maxEpisodes);
trainingStats = train(agent,env,trainingOptions);

timestamp = string(datetime("now","Format","yyyyMMdd_HHmmss"));
outputFile = fullfile(projectRoot,"results","coverage_dqn_" + P.rl.profile + "_" + timestamp + ".mat");
save(outputFile,"agent","trainingStats","P","scenario","-v7.3");
fprintf("Eğitim kaydedildi: %s\n",outputFile);
end
