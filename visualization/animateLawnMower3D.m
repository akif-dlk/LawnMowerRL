function viewer = animateLawnMower3D(simResult, scenario, P, cameraMode)
%ANIMATELAWNMOWER3D Simülasyon sonucunu 3D bahçe ve robot ortamında canlandırır.
%
% Kullanım:
%   viewer = animateLawnMower3D(simResult)
%   viewer = animateLawnMower3D(simResult, scenario, P, "chase")
%
% Kamera Modları:
%   "chase"   : Robotu arkadan takip eden 3. şahıs kamerası (varsayılan)
%   "topdown" : Tüm bahçeyi gösteren kuşbakışı kamera
%   "orbit"   : Serbest 3D döndürülebilir kamera
%   "cockpit" : Ön sensör/kokpit kamerası

arguments
    simResult struct
    scenario struct = struct()
    P struct = struct()
    cameraMode (1,1) string = "chase"
end

if isempty(fieldnames(P))
    if isfield(simResult, "P")
        P = simResult.P;
    else
        P = robotParameters("quick");
    end
end

if isempty(fieldnames(scenario))
    if isfield(simResult, "scenario")
        scenario = simResult.scenario;
    else
        scenario = createGardenScenario(P, "demo");
    end
end

% Verileri ayıkla
if isfield(simResult, "sim")
    simData = simResult.sim;
else
    simData = simResult;
end

time = simData.time;
x = simData.x;
y = simData.y;
psi = simData.psi;

if isfield(simData, "v")
    v = simData.v;
else
    v = zeros(size(x));
end

if isfield(simData, "w")
    w = simData.w;
else
    w = zeros(size(x));
end

if isfield(simData, "energyWh")
    energyWh = simData.energyWh;
elseif isfield(simData, "energy_Wh")
    energyWh = simData.energy_Wh;
else
    energyWh = zeros(size(x));
end

if isfield(simData, "soc")
    soc = simData.soc;
else
    soc = ones(size(x));
end

% 3D Viewer oluştur ve canlandır
viewer = LawnMower3DViewer(scenario, P, cameraMode);
viewer.animateTrajectory(time, x, y, psi, v, w, energyWh, soc);
end
