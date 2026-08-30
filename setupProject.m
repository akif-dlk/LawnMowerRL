function projectRoot = setupProject()
%SETUPPROJECT Proje klasörlerini MATLAB yoluna ekler.

projectRoot = fileparts(mfilename("fullpath"));
addpath(projectRoot);
addpath(fullfile(projectRoot, "config"));
addpath(fullfile(projectRoot, "models"));
addpath(fullfile(projectRoot, "planning"));
addpath(fullfile(projectRoot, "scenarios"));
addpath(fullfile(projectRoot, "simulation"));
addpath(fullfile(projectRoot, "visualization"));
addpath(fullfile(projectRoot, "tests"));

if ~isfolder(fullfile(projectRoot, "results"))
    mkdir(fullfile(projectRoot, "results"));
end

fprintf("LawnMowerRL hazır: %s\n", projectRoot);
end

