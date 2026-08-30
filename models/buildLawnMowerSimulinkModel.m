function modelPath = buildLawnMowerSimulinkModel(P, openModel)
%BUILDLAWNMOWERSIMULINKMODEL 2D çim biçme robotu Simulink modelini üretir.
%
% Girdiler base workspace'teki v_cmd_ts ve w_cmd_ts timeseries nesneleridir.
% Çıktılar sim_x, sim_y, sim_psi, sim_v, sim_w, sim_wheel_left,
% sim_wheel_right, sim_energy_Wh ve sim_soc olarak kaydedilir.

arguments
    P struct = robotParameters()
    openModel (1,1) logical = true
end

modelName = "LawnMowerPlant";
projectRoot = fileparts(fileparts(mfilename("fullpath")));
modelPath = fullfile(projectRoot, "models", modelName + ".slx");

% Model tek başına açıldığında da güncellenebilsin diye güvenli varsayılan girişler.
if evalin("base","exist('v_cmd_ts','var')") == 0
    assignin("base","v_cmd_ts",timeseries([0;0],[0;10]));
end
if evalin("base","exist('w_cmd_ts','var')") == 0
    assignin("base","w_cmd_ts",timeseries([0;0],[0;10]));
end
if evalin("base","exist('simStopTime','var')") == 0
    assignin("base","simStopTime",10);
end

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
new_system(modelName);
load_system("simulink");

set_param(modelName, ...
    "Solver", "ode45", ...
    "StopTime", "simStopTime", ...
    "SignalLogging", "on", ...
    "SaveTime", "on", ...
    "SaveOutput", "on");

% Kaynaklar ve tahrik dinamiği.
add_block("simulink/Sources/From Workspace", modelName + "/v_cmd", ...
    "VariableName", "v_cmd_ts", "Interpolate", "on", "Position", [35 75 145 105]);
add_block("simulink/Sources/From Workspace", modelName + "/w_cmd", ...
    "VariableName", "w_cmd_ts", "Interpolate", "on", "Position", [35 185 145 215]);

add_block("simulink/Discontinuities/Saturation", modelName + "/v_limit", ...
    "UpperLimit", num2str(P.drive.maxLinearSpeed,17), ...
    "LowerLimit", num2str(-P.drive.maxLinearSpeed,17), "Position", [180 72 245 108]);
add_block("simulink/Discontinuities/Saturation", modelName + "/w_limit", ...
    "UpperLimit", num2str(P.drive.maxYawRate,17), ...
    "LowerLimit", num2str(-P.drive.maxYawRate,17), "Position", [180 182 245 218]);

add_block("simulink/Continuous/Transfer Fcn", modelName + "/linear_drive", ...
    "Numerator", "1", "Denominator", sprintf("[%g 1]", P.drive.linearTimeConstant), ...
    "Position", [285 70 375 110]);
add_block("simulink/Continuous/Transfer Fcn", modelName + "/yaw_drive", ...
    "Numerator", "1", "Denominator", sprintf("[%g 1]", P.drive.yawTimeConstant), ...
    "Position", [285 180 375 220]);

% Yaw ve düzlem kinematiği.
add_block("simulink/Continuous/Integrator", modelName + "/psi", ...
    "InitialCondition", num2str(P.sim.initialPose(3),17), "Position", [445 178 480 212]);
add_block("simulink/Math Operations/Trigonometric Function", modelName + "/cos_psi", ...
    "Operator", "cos", "Position", [525 120 580 155]);
add_block("simulink/Math Operations/Trigonometric Function", modelName + "/sin_psi", ...
    "Operator", "sin", "Position", [525 245 580 280]);
add_block("simulink/Math Operations/Product", modelName + "/x_dot", ...
    "Inputs", "**", "Position", [625 72 665 108]);
add_block("simulink/Math Operations/Product", modelName + "/y_dot", ...
    "Inputs", "**", "Position", [625 245 665 281]);
add_block("simulink/Continuous/Integrator", modelName + "/x", ...
    "InitialCondition", num2str(P.sim.initialPose(1),17), "Position", [710 72 745 108]);
add_block("simulink/Continuous/Integrator", modelName + "/y", ...
    "InitialCondition", num2str(P.sim.initialPose(2),17), "Position", [710 245 745 281]);

% Sol/sağ teker açısal hızları.
add_block("simulink/Math Operations/Gain", modelName + "/half_track", ...
    "Gain", num2str(P.body.trackWidth/2,17), "Position", [430 330 500 365]);
add_block("simulink/Math Operations/Sum", modelName + "/v_right", ...
    "Inputs", "++", "Position", [555 310 585 350]);
add_block("simulink/Math Operations/Sum", modelName + "/v_left", ...
    "Inputs", "+-", "Position", [555 380 585 420]);
add_block("simulink/Math Operations/Gain", modelName + "/wheel_right", ...
    "Gain", num2str(1/P.wheel.radius,17), "Position", [625 312 705 348]);
add_block("simulink/Math Operations/Gain", modelName + "/wheel_left", ...
    "Gain", num2str(1/P.wheel.radius,17), "Position", [625 382 705 418]);

% Güç ve batarya modeli.
add_block("simulink/Math Operations/Abs", modelName + "/abs_v", ...
    "Position", [420 490 455 525]);
add_block("simulink/Math Operations/Abs", modelName + "/abs_w", ...
    "Position", [420 555 455 590]);
add_block("simulink/Math Operations/Gain", modelName + "/linear_power", ...
    "Gain", num2str(P.energy.linearCoeff,17), "Position", [485 487 560 528]);
add_block("simulink/Math Operations/Gain", modelName + "/yaw_power", ...
    "Gain", num2str(P.energy.yawCoeff,17), "Position", [485 552 560 593]);
add_block("simulink/Sources/Constant", modelName + "/base_power", ...
    "Value", num2str(P.energy.idlePower + P.cutting.bladePower,17), ...
    "Position", [475 635 560 665]);
add_block("simulink/Math Operations/Sum", modelName + "/total_power_W", ...
    "Inputs", "+++", "Position", [615 535 645 595]);
add_block("simulink/Math Operations/Gain", modelName + "/W_to_Wh_per_s", ...
    "Gain", "1/3600", "Position", [680 545 755 585]);
add_block("simulink/Continuous/Integrator", modelName + "/energy_Wh", ...
    "InitialCondition", "0", "Position", [795 547 830 583]);
add_block("simulink/Math Operations/Gain", modelName + "/negative_soc_drop", ...
    "Gain", num2str(-1/P.battery.capacityWh,17), "Position", [870 545 955 585]);
add_block("simulink/Sources/Constant", modelName + "/full_soc", ...
    "Value", "1", "Position", [875 620 930 650]);
add_block("simulink/Math Operations/Sum", modelName + "/soc", ...
    "Inputs", "++", "Position", [990 565 1020 615]);

% Çıktıları Workspace'e yaz.
addToWorkspace(modelName, "save_x", "sim_x", [810 55 915 85]);
addToWorkspace(modelName, "save_y", "sim_y", [810 235 915 265]);
addToWorkspace(modelName, "save_psi", "sim_psi", [810 160 915 190]);
addToWorkspace(modelName, "save_v", "sim_v", [810 105 915 135]);
addToWorkspace(modelName, "save_w", "sim_w", [810 200 915 230]);
addToWorkspace(modelName, "save_wheel_right", "sim_wheel_right", [760 315 895 345]);
addToWorkspace(modelName, "save_wheel_left", "sim_wheel_left", [760 385 895 415]);
addToWorkspace(modelName, "save_energy", "sim_energy_Wh", [865 485 985 515]);
addToWorkspace(modelName, "save_soc", "sim_soc", [1060 575 1165 605]);

% Bağlantılar.
wire(modelName, "v_cmd/1", "v_limit/1");
wire(modelName, "v_limit/1", "linear_drive/1");
wire(modelName, "w_cmd/1", "w_limit/1");
wire(modelName, "w_limit/1", "yaw_drive/1");
wire(modelName, "yaw_drive/1", "psi/1");
wire(modelName, "psi/1", "cos_psi/1");
wire(modelName, "psi/1", "sin_psi/1");
wire(modelName, "linear_drive/1", "x_dot/1");
wire(modelName, "cos_psi/1", "x_dot/2");
wire(modelName, "x_dot/1", "x/1");
wire(modelName, "linear_drive/1", "y_dot/1");
wire(modelName, "sin_psi/1", "y_dot/2");
wire(modelName, "y_dot/1", "y/1");

wire(modelName, "yaw_drive/1", "half_track/1");
wire(modelName, "linear_drive/1", "v_right/1");
wire(modelName, "linear_drive/1", "v_left/1");
wire(modelName, "half_track/1", "v_right/2");
wire(modelName, "half_track/1", "v_left/2");
wire(modelName, "v_right/1", "wheel_right/1");
wire(modelName, "v_left/1", "wheel_left/1");

wire(modelName, "linear_drive/1", "abs_v/1");
wire(modelName, "yaw_drive/1", "abs_w/1");
wire(modelName, "abs_v/1", "linear_power/1");
wire(modelName, "abs_w/1", "yaw_power/1");
wire(modelName, "linear_power/1", "total_power_W/1");
wire(modelName, "yaw_power/1", "total_power_W/2");
wire(modelName, "base_power/1", "total_power_W/3");
wire(modelName, "total_power_W/1", "W_to_Wh_per_s/1");
wire(modelName, "W_to_Wh_per_s/1", "energy_Wh/1");
wire(modelName, "energy_Wh/1", "negative_soc_drop/1");
wire(modelName, "negative_soc_drop/1", "soc/1");
wire(modelName, "full_soc/1", "soc/2");

wire(modelName, "x/1", "save_x/1");
wire(modelName, "y/1", "save_y/1");
wire(modelName, "psi/1", "save_psi/1");
wire(modelName, "linear_drive/1", "save_v/1");
wire(modelName, "yaw_drive/1", "save_w/1");
wire(modelName, "wheel_right/1", "save_wheel_right/1");
wire(modelName, "wheel_left/1", "save_wheel_left/1");
wire(modelName, "energy_Wh/1", "save_energy/1");
wire(modelName, "soc/1", "save_soc/1");

Simulink.BlockDiagram.arrangeSystem(modelName);
save_system(modelName, modelPath);

if openModel
    open_system(modelName);
else
    close_system(modelName, 0);
end

fprintf("Simulink modeli üretildi: %s\n", modelPath);
end

function addToWorkspace(modelName, blockName, variableName, position)
add_block("simulink/Sinks/To Workspace", modelName + "/" + blockName, ...
    "VariableName", variableName, "SaveFormat", "Timeseries", "Position", position);
end

function wire(modelName, sourcePort, destinationPort)
add_line(modelName, sourcePort, destinationPort, "autorouting", "on");
end
