function scenario = createGardenScenario(P, scenarioName, seed)
%CREATEGARDENSCENARIO Tez deneyleri için zenginleştirilmiş bahçe ve engebeli arazi haritası üretir.
%
% Çıktı alanları:
%   obstacleMask          : Engelli hücreler (ev, ağaç, çiçeklik, taş)
%   freeMask              : Serbest hareket edilebilen hücreler
%   inflatedObstacleMask  : Robot basefootprint güvenlik payı eklenmiş engel haritası
%   elevationGrid         : 3D arazi tepe/vadi yükseklik matrisi (rows+1 x cols+1)
%   structures            : 3D nesnelerin tam dünya koordinatları ve boyutları

arguments
    P struct = robotParameters()
    scenarioName (1,1) string {mustBeMember(scenarioName,["open","demo","narrow","random"])} = "demo"
    seed (1,1) double = P.rl.randomSeed
end

rng(seed, "twister");
rows = P.coverage.rows;
cols = P.coverage.cols;
cellSize = P.coverage.cellSize;
obstacles = false(rows, cols);

% Yapı listeleri
structures.trees = zeros(0,4);      % [centerX, centerY, radius, height]
structures.flowerbeds = zeros(0,4); % [xMin, xMax, yMin, yMax]
structures.houses = zeros(0,5);     % [xMin, xMax, yMin, yMax, height]
structures.sheds = zeros(0,5);      % [xMin, xMax, yMin, yMax, height]

switch scenarioName
    case "open"
        % Açık dikdörtgen bahçe

    case "demo"
        % 1. Bahçe Evi / Villa (Girilmez Yapı)
        houseRows = 16:21;
        houseCols = 25:31;
        obstacles(houseRows, houseCols) = true;
        structures.houses(1,:) = [ ...
            (houseCols(1)-1)*cellSize, houseCols(end)*cellSize, ...
            (houseRows(1)-1)*cellSize, houseRows(end)*cellSize, 1.8];
        
        % 2. Ağaç Korusu (Dairesel Ada)
        [cc, rr] = meshgrid(1:cols, 1:rows);
        treeCenterRow = 9; treeCenterCol = 12; treeRadiusCells = 2.5;
        treeMask = ((rr-treeCenterRow).^2 + (cc-treeCenterCol).^2 <= treeRadiusCells^2);
        obstacles = obstacles | treeMask;
        structures.trees(1,:) = [ ...
            (treeCenterCol-0.5)*cellSize, (treeCenterRow-0.5)*cellSize, 0.9, 2.2];
        
        % 3. Çiçeklik (Yükseltilmiş Tarh)
        flowerRows = 4:7;
        flowerCols = 27:32;
        obstacles(flowerRows, flowerCols) = true;
        structures.flowerbeds(1,:) = [ ...
            (flowerCols(1)-1)*cellSize, flowerCols(end)*cellSize, ...
            (flowerRows(1)-1)*cellSize, flowerRows(end)*cellSize];
        
        % 4. Taş Bahçesi / Alet Kulübesi
        shedRows = 15:18;
        shedCols = 5:8;
        obstacles(shedRows, shedCols) = true;
        structures.sheds(1,:) = [ ...
            (shedCols(1)-1)*cellSize, shedCols(end)*cellSize, ...
            (shedRows(1)-1)*cellSize, shedRows(end)*cellSize, 0.8];

    case "narrow"
        % Dar geçitli bahçe
        obstacles(6:19, 11:13) = true;
        obstacles(6:19, 23:25) = true;
        obstacles(11:13, 14:22) = true;

    case "random"
        targetDensity = 0.10;
        obstacles = rand(rows, cols) < targetDensity;
        neighbors = conv2(double(obstacles), ones(3), "same");
        obstacles = neighbors >= 3;
end

startCell = [2 2]; % [row col]
obstacles(startCell(1), startCell(2)) = false;

% Başlangıç bölgesini ve sınır koridorlarını açık tut
obstacles(1:3, 1:4) = false;
obstacles(1, :) = false;
obstacles(:, 1) = false;

% Basefootprint güvenlik payı (Dilation / Inflation)
% Robotun fiziksel yarıçapı kadar (1 hücre) engellerin etrafında koruma payı
footprintKernel = [0 1 0; 1 1 1; 0 1 0];
inflated = conv2(double(obstacles), footprintKernel, "same") > 0;
inflated(startCell(1), startCell(2)) = false;
inflated(1, :) = false;
inflated(:, 1) = false;

% 3D Engebeli Arazi Yükseklik Matrisi (Elevation Map)
[Xgrid, Ygrid] = meshgrid(linspace(0, cols*cellSize, cols+1), ...
                          linspace(0, rows*cellSize, rows+1));

if isfield(P, "terrain") && isfield(P.terrain, "enabled") && P.terrain.enabled
    A = P.terrain.elevationAmplitude;
    lx = P.terrain.wavelengthX;
    ly = P.terrain.wavelengthY;
    
    % Pürüzsüz dalgalı tepecikler ve vadiler
    elevationGrid = A * (sin(2*pi*Xgrid/lx) .* cos(2*pi*Ygrid/ly) + ...
                         0.35 * cos(2*pi*(Xgrid + 0.5*Ygrid)/8.5));
    % Sınır çitlerinde yumuşak sıfırlama
    elevationGrid = elevationGrid - min(elevationGrid(:));
else
    elevationGrid = zeros(size(Xgrid));
end

scenario.name = scenarioName;
scenario.seed = seed;
scenario.obstacleMask = logical(obstacles);
scenario.freeMask = ~scenario.obstacleMask;
scenario.inflatedObstacleMask = logical(inflated);
scenario.startCell = startCell;
scenario.startHeading = 2; % 1=N, 2=E, 3=S, 4=W
scenario.rows = rows;
scenario.cols = cols;
scenario.cellSize = cellSize;
scenario.width = cols * cellSize;
scenario.height = rows * cellSize;
scenario.freeCellCount = nnz(scenario.freeMask);
scenario.elevationGrid = elevationGrid;
scenario.structures = structures;

% İki boyutlu sürekli konuma göre arazi yüksekliği ve gradyanı fonksiyonu
scenario.getElevation = @(x,y) interp2(Xgrid, Ygrid, elevationGrid, ...
    min(max(x, 0), cols*cellSize), min(max(y, 0), rows*cellSize), "spline");

end
