function P = robotParameters(profile)
%ROBOTPARAMETERS Robot, enerji, kapsama ve RL parametrelerini döndürür.
%
% P = robotParameters("quick")  : kısa doğrulama eğitimi
% P = robotParameters("thesis") : uzun, tekrarlı tez deneyi

arguments
    profile (1,1) string {mustBeMember(profile,["quick","thesis"])} = "quick"
end

P.meta.name = "LMR-680 Research Mower";
P.meta.version = "0.1.0";
P.meta.targetMatlab = "R2024b+";

% Mekanik ölçüler [SI]
P.body.length = 0.680;
P.body.width = 0.520;
P.body.height = 0.290;
P.body.mass = 24.0;
P.body.wheelbase = 0.420;
P.body.trackWidth = 0.460;
P.body.footprintRadius = 0.5 * hypot(P.body.length, P.body.width); % Güvenli çevreleyen yarıçap (~0.43 m)
P.wheel.radius = 0.110;
P.wheel.width = 0.060;

% Tahrik: fiziksel olarak dört teker, kontrol açısından iki taraflı skid-steer.
P.drive.layout = "4WD-left-right-coupled";
P.drive.maxLinearSpeed = 0.80;
P.drive.nominalMowingSpeed = 0.45;
P.drive.maxYawRate = 0.90;
P.drive.linearTimeConstant = 0.35;
P.drive.yawTimeConstant = 0.25;

% Engebeli arazi parametreleri
P.terrain.enabled = true;
P.terrain.elevationAmplitude = 0.35; % m (dalgalı tepe/vadi yüksekliği)
P.terrain.wavelengthX = 7.0;        % m
P.terrain.wavelengthY = 5.0;        % m

% Biçme sistemi
P.cutting.width = 0.400;
P.cutting.heightRange = [0.020 0.070];
P.cutting.discCount = 2;
P.cutting.bladesPerDisc = 3;
P.cutting.bladePower = 180.0;
P.cutting.targetOverlap = 0.10;

% Basit enerji modeli
P.battery.voltage = 36.0;
P.battery.capacityAh = 15.0;
P.battery.capacityWh = P.battery.voltage * P.battery.capacityAh;
P.energy.idlePower = 18.0;
P.energy.linearCoeff = 115.0;  % W/(m/s)
P.energy.yawCoeff = 45.0;     % W/(rad/s)
P.energy.slopeCoeff = P.body.mass * 9.81; % Eğim direnci W/(m/s * sin(theta))

% Simülasyon ve takip
P.sim.sampleTime = 0.10;
P.sim.initialPose = [0.2 0.2 0.0];
P.control.headingGain = 2.4;
P.control.waypointTolerance = 0.08;
P.control.slowdownDistance = 0.45;
P.control.maxCommandSteps = 150000;

% Kapsama haritası: 24x36 hücre ve 0.4 m hücre = 14.4 x 9.6 m bahçe.
P.coverage.rows = 24;
P.coverage.cols = 36;
P.coverage.cellSize = P.cutting.width;
P.coverage.targetRatio = 0.98;

% Ödül terimleri
P.reward.newCell = 1.00;
P.reward.revisit = -0.22;
P.reward.step = -0.025;
P.reward.turnPerQuarter = -0.10;
P.reward.invalidMove = -2.00;
P.reward.energyPerWh = -0.030;
P.reward.completion = 30.0;
P.reward.progressPotential = 0.04;

% RL hiperparametreleri
P.rl.profile = profile;
P.rl.discountFactor = 0.995;
P.rl.miniBatchSize = 128;
P.rl.experienceBufferLength = 200000;
P.rl.targetUpdateFrequency = 4;
P.rl.epsilon = 1.0;
P.rl.epsilonMin = 0.02;
P.rl.epsilonDecay = 2e-5;
P.rl.learningRate = 5e-4;
P.rl.maxSteps = 4 * P.coverage.rows * P.coverage.cols;
P.rl.randomSeed = 42;

switch profile
    case "quick"
        P.rl.maxEpisodes = 150;
        P.rl.scoreWindow = 20;
        P.rl.stopAverageReward = 350;
        P.rl.useParallel = false;
    case "thesis"
        P.rl.maxEpisodes = 5000;
        P.rl.scoreWindow = 100;
        P.rl.stopAverageReward = 500;
        P.rl.useParallel = true;
end
end
