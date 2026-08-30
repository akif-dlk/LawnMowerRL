function [pathXY, pathCells] = generateBoustrophedonBaseline(scenario)
%GENERATEBOUSTROPHEDONBASELINE Engelleri BFS ile dolaşan serpantin kapsama.
% Her serbest hücre satır satır hedeflenir. Kopuk satır parçaları arasında
% en kısa 4-komşuluk yolu kullanılır; tekrar geçişler metrikte tutulur.

pathCells = scenario.startCell;
current = scenario.startCell;

for row = 1:scenario.rows
    freeCols = find(scenario.freeMask(row,:));
    freeCols = freeCols(:).';
    if mod(row,2) == 0
        freeCols = fliplr(freeCols);
    end

    for col = freeCols
        target = [row col];
        if isequal(target, current)
            continue;
        end
        connector = shortestGridPath(current, target, scenario.freeMask);
        if isempty(connector)
            warning("Ulaşılamayan serbest hücre atlandı: row=%d col=%d", row, col);
            continue;
        end
        pathCells = [pathCells; connector(2:end,:)]; %#ok<AGROW>
        current = target;
    end
end

pathXY = cellsToWorld(pathCells, scenario);
end

function path = shortestGridPath(startCell, goalCell, freeMask)
rows = size(freeMask,1);
cols = size(freeMask,2);
cellCount = rows * cols;
startIdx = sub2ind([rows cols], startCell(1), startCell(2));
goalIdx = sub2ind([rows cols], goalCell(1), goalCell(2));

visited = false(cellCount,1);
parent = zeros(cellCount,1,"uint32");
queue = zeros(cellCount,1,"uint32");
head = 1;
tail = 1;
queue(tail) = uint32(startIdx);
visited(startIdx) = true;
directions = [1 0; 0 1; -1 0; 0 -1];

found = false;
while head <= tail
    currentIdx = double(queue(head));
    head = head + 1;
    if currentIdx == goalIdx
        found = true;
        break;
    end
    [row,col] = ind2sub([rows cols], currentIdx);
    for k = 1:4
        nr = row + directions(k,1);
        nc = col + directions(k,2);
        if nr < 1 || nr > rows || nc < 1 || nc > cols || ~freeMask(nr,nc)
            continue;
        end
        nextIdx = sub2ind([rows cols], nr, nc);
        if ~visited(nextIdx)
            visited(nextIdx) = true;
            parent(nextIdx) = uint32(currentIdx);
            tail = tail + 1;
            queue(tail) = uint32(nextIdx);
        end
    end
end

if ~found
    path = zeros(0,2);
    return;
end

reverseIndices = zeros(cellCount,1,"uint32");
count = 1;
reverseIndices(count) = uint32(goalIdx);
cursor = goalIdx;
while cursor ~= startIdx
    cursor = double(parent(cursor));
    if cursor == 0
        path = zeros(0,2);
        return;
    end
    count = count + 1;
    reverseIndices(count) = uint32(cursor);
end

indices = double(flipud(reverseIndices(1:count)));
[pathRows,pathCols] = ind2sub([rows cols], indices);
path = [pathRows pathCols];
end
