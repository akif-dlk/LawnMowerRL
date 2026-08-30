function scenario = createGardenScenario(P, scenarioName, seed)
%CREATEGARDENSCENARIO Tez deneyleri için bahçe doluluk haritası üretir.
% obstacleMask: true hücreler robotun giremeyeceği alanlardır.

arguments
    P struct = robotParameters()
    scenarioName (1,1) string {mustBeMember(scenarioName,["open","demo","narrow","random"])} = "demo"
    seed (1,1) double = P.rl.randomSeed
end

rng(seed, "twister");
rows = P.coverage.rows;
cols = P.coverage.cols;
obstacles = false(rows, cols);

switch scenarioName
    case "open"
        % Referans açık dikdörtgen.

    case "demo"
        % Ağaç adası, çiçeklik ve küçük yapı.
        [cc, rr] = meshgrid(1:cols, 1:rows);
        obstacles = obstacles | ((rr-7).^2 + (cc-10).^2 <= 2.2^2);
        obstacles(13:16, 21:24) = true;
        obstacles(4:6, 25:27) = true;

    case "narrow"
        obstacles(5:16, 10:12) = true;
        obstacles(5:16, 19:21) = true;
        obstacles(9:11, 13:18) = true;

    case "random"
        targetDensity = 0.10;
        obstacles = rand(rows, cols) < targetDensity;
        % Tek hücrelik gürültüyü küçük kümelere dönüştür.
        neighbors = conv2(double(obstacles), ones(3), "same");
        obstacles = neighbors >= 3;
end

startCell = [2 2]; % [row col]
obstacles(startCell(1), startCell(2)) = false;

% Başlangıç bölgesini ve sınır boyunca en az bir bağlantı koridorunu açık tut.
obstacles(1:3, 1:4) = false;
obstacles(1, :) = false;
obstacles(:, 1) = false;

scenario.name = scenarioName;
scenario.seed = seed;
scenario.obstacleMask = logical(obstacles);
scenario.freeMask = ~scenario.obstacleMask;
scenario.startCell = startCell;
scenario.startHeading = 2; % 1=N, 2=E, 3=S, 4=W
scenario.rows = rows;
scenario.cols = cols;
scenario.cellSize = P.coverage.cellSize;
scenario.width = cols * scenario.cellSize;
scenario.height = rows * scenario.cellSize;
scenario.freeCellCount = nnz(scenario.freeMask);
end

