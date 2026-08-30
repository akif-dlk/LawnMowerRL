function xy = cellsToWorld(cells, scenario)
%CELLSTOWORLD [row col] hücrelerini hücre merkezi [x y] koordinatına çevirir.

if isempty(cells)
    xy = zeros(0,2);
    return;
end

validateattributes(cells, {'numeric'}, {'ncols',2,'integer','positive'});
x = (cells(:,2) - 0.5) * scenario.cellSize;
y = (cells(:,1) - 0.5) * scenario.cellSize;
xy = [x y];
end
