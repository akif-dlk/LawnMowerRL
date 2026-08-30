function [vCmdTs, wCmdTs, meta] = pathToCommands(pathXY, P)
%PATHTOCOMMANDS Yol noktalarını diferansiyel robot hız komutlarına çevirir.
% Komut üretimi ideal kinematik üzerinde waypoint takipçisiyle yapılır.

arguments
    pathXY (:,2) double
    P struct = robotParameters()
end

assert(size(pathXY,1) >= 2, "Rota en az iki noktadan oluşmalıdır.");

Ts = P.sim.sampleTime;
initialHeading = atan2(pathXY(2,2)-pathXY(1,2), pathXY(2,1)-pathXY(1,1));
pose = [pathXY(1,:) initialHeading];
targetIndex = 2;

time = zeros(P.control.maxCommandSteps,1);
v = zeros(P.control.maxCommandSteps,1);
w = zeros(P.control.maxCommandSteps,1);
idealPose = zeros(P.control.maxCommandSteps,3);
count = 1;
idealPose(1,:) = pose;

while targetIndex <= size(pathXY,1) && count < P.control.maxCommandSteps
    target = pathXY(targetIndex,:);
    delta = target - pose(1:2);
    distance = hypot(delta(1), delta(2));

    if distance <= P.control.waypointTolerance
        targetIndex = targetIndex + 1;
        continue;
    end

    desiredHeading = atan2(delta(2), delta(1));
    headingError = wrapAngle(desiredHeading - pose(3));

    wNow = clamp(P.control.headingGain * headingError, ...
        -P.drive.maxYawRate, P.drive.maxYawRate);
    alignment = max(0.0, cos(headingError));
    slowdown = min(1.0, distance / P.control.slowdownDistance);
    vNow = P.drive.nominalMowingSpeed * alignment^2 * slowdown;

    % Keskin dönüşte ilerlemeyi durdurarak köşe kesmeyi azalt.
    if abs(headingError) > pi/3
        vNow = 0;
    end

    count = count + 1;
    time(count) = time(count-1) + Ts;
    v(count) = vNow;
    w(count) = wNow;

    pose(1) = pose(1) + Ts*vNow*cos(pose(3));
    pose(2) = pose(2) + Ts*vNow*sin(pose(3));
    pose(3) = wrapAngle(pose(3) + Ts*wNow);
    idealPose(count,:) = pose;
end

if targetIndex <= size(pathXY,1)
    warning("Komut üretimi maksimum adım sayısına ulaştı; rota kısaltılmış olabilir.");
end

% Son örnekte dur.
count = count + 1;
time(count) = time(count-1) + Ts;
v(count) = 0;
w(count) = 0;
idealPose(count,:) = pose;

time = time(1:count);
v = v(1:count);
w = w(1:count);
idealPose = idealPose(1:count,:);

vCmdTs = timeseries(v, time);
wCmdTs = timeseries(w, time);
vCmdTs.Name = "v_cmd";
wCmdTs.Name = "w_cmd";

meta.time = time;
meta.v = v;
meta.w = w;
meta.idealPose = idealPose;
meta.reachedWaypointCount = min(targetIndex-1, size(pathXY,1));
meta.totalWaypointCount = size(pathXY,1);
meta.duration = time(end);
end

function angle = wrapAngle(angle)
angle = atan2(sin(angle), cos(angle));
end

function value = clamp(value, low, high)
value = min(max(value, low), high);
end

