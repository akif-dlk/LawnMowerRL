classdef LawnMower3DViewer < handle
    %LAWNMOWER3DVIEWER Otonom çim biçme robotu için 3D ve canlı görselleştirici.
    %
    % Özellikler:
    %   - 3D Robot Montajı: Şasiye paralel 4 tekerlek, dönen kesici diskler, RTK, LiDAR ve LED farlar
    %   - Engebeli 3D Bahçe ve Yükseklik Haritası: Eğimli tepe/vadiler, dinamik çim biçme şeritleri
    %   - Gerçekçi 3D Yapılar: Bahçe Evi/Villa, Çiçeklik, Ağaç Korusu, Alet Kulübesi ve Ahşap Çit
    %   - Araziye Oturan Robot: Z kotu, anlık pitch ve roll açıları ile yokuş eğim adaptasyonu
    %   - Çoklu Kamera: Chase Cam (Takip), Top-Down (Kuşbakışı), Orbit (Serbest 3D), Cockpit (Sensör)
    %   - Canlı Telemetri ve HUD: Hız, eğim, kapsama %, batarya SoC %, anlık güç ve enerji

    properties
        Figure
        Axes
        Scenario
        P
        CameraMode = "chase"   % "chase", "topdown", "orbit", "cockpit"
        PlaybackSpeed = 1.0     % Simülasyon hız çarpanı
        IsPaused = false
        IsMowing = true
        
        % 3D Grafik nesneleri
        RobotTransform
        CutterTransform
        WheelTransforms = gobjects(0)
        GrassSurface
        TrailLine
        HudText
        HudPanel
        
        % Çim ve Kapsama Durumu
        CutGrid
        BladeAngle = 0
        WheelAngle = 0
        TrailPoints = zeros(0,3)
        MaxTrailLength = 800
    end
    
    properties (Access = private)
        FigControls = struct()
    end

    methods
        function obj = LawnMower3DViewer(scenario, P, cameraMode)
            % Kurucu fonksiyon: 3D sahneyi ve robot modelini inşa eder.
            arguments
                scenario struct = struct()
                P struct = struct()
                cameraMode (1,1) string = "chase"
            end
            
            if isempty(fieldnames(P))
                P = robotParameters("quick");
            end
            if isempty(fieldnames(scenario))
                scenario = createGardenScenario(P, "demo");
            end
            
            obj.Scenario = scenario;
            obj.P = P;
            obj.CameraMode = cameraMode;
            obj.CutGrid = zeros(scenario.rows, scenario.cols); % 0: biçilmemiş, 1: biçilmiş
            
            obj.createScene();
            obj.buildGardenEnvironment();
            obj.build3DRobot();
            obj.buildHUD();
            obj.setCameraMode(obj.CameraMode);
            
            drawnow;
        end
        
        function setCameraMode(obj, mode)
            % Kamera modunu ayarlar ("chase", "topdown", "orbit", "cockpit").
            obj.CameraMode = mode;
            if isfield(obj.FigControls, "CamPopup") && isvalid(obj.FigControls.CamPopup)
                switch mode
                    case "chase", obj.FigControls.CamPopup.Value = 1;
                    case "topdown", obj.FigControls.CamPopup.Value = 2;
                    case "orbit", obj.FigControls.CamPopup.Value = 3;
                    case "cockpit", obj.FigControls.CamPopup.Value = 4;
                end
            end
        end
        
        function updatePose(obj, x, y, psi, v, w, energyWh, soc, t)
            % Robotun anlık konum, eğim ve telemetri durumunu günceller.
            arguments
                obj
                x (1,1) double
                y (1,1) double
                psi (1,1) double
                v (1,1) double = 0
                w (1,1) double = 0
                energyWh (1,1) double = 0
                soc (1,1) double = 1.0
                t (1,1) double = 0
            end
            
            if ~isvalid(obj.Figure) || ~isvalid(obj.Axes)
                return;
            end
            
            % 1. Engebeli arazide zemin yüksekliği ve eğim gradyanı
            zGround = obj.getTerrainHeight(x, y);
            [pitchAngle, rollAngle] = obj.getTerrainAngles(x, y, psi);
            zRobot = zGround + obj.P.wheel.radius * cos(pitchAngle);
            
            % 2. Robot ana transformasyon matrisini güncelle (X, Y, Z, Yaw, Pitch, Roll)
            M = makehgtform('translate', [x, y, zRobot], ...
                           'zrotate', psi, ...
                           'yrotate', pitchAngle, ...
                           'xrotate', rollAngle);
            set(obj.RobotTransform, 'Matrix', M);
            
            % 3. Kesici disklerin yüksek hızlı dönüş animasyonu (Biçme aktifken)
            if obj.IsMowing
                obj.BladeAngle = mod(obj.BladeAngle + 0.45, 2*pi);
                set(obj.CutterTransform, 'Matrix', makehgtform('zrotate', obj.BladeAngle));
            end
            
            % 4. Tekerleklerin şasiye paralel ileri yuvarlanma dönüşü (Y ekseninde)
            obj.WheelAngle = mod(obj.WheelAngle + (v * 0.1 / max(0.01, obj.P.wheel.radius)), 2*pi);
            for k = 1:numel(obj.WheelTransforms)
                if isvalid(obj.WheelTransforms(k))
                    set(obj.WheelTransforms(k), 'Matrix', makehgtform('yrotate', obj.WheelAngle));
                end
            end
            
            % 5. Çim biçme izi ve kapsama matrisini güncelle
            obj.updateCuttingGrid(x, y);
            
            % 6. Rota iz çizgisi (arazi yüzeyinin hemen üzerinde)
            obj.TrailPoints(end+1,:) = [x, y, zGround + 0.04];
            if size(obj.TrailPoints, 1) > obj.MaxTrailLength
                obj.TrailPoints(1,:) = [];
            end
            set(obj.TrailLine, 'XData', obj.TrailPoints(:,1), ...
                              'YData', obj.TrailPoints(:,2), ...
                              'ZData', obj.TrailPoints(:,3));
            
            % 7. Kamera takibi
            obj.updateCamera(x, y, zRobot, psi, pitchAngle);
            
            % 8. HUD Telemetri göstergeleri
            obj.updateHUD(x, y, psi, v, w, pitchAngle, energyWh, soc, t);
        end
        
        function animateTrajectory(obj, time, x, y, psi, v, w, energyWh, soc)
            % Kaydedilmiş bir simülasyon zaman serisini 3D olarak oynatır.
            arguments
                obj
                time (:,1) double
                x (:,1) double
                y (:,1) double
                psi (:,1) double
                v (:,1) double = zeros(size(x))
                w (:,1) double = zeros(size(x))
                energyWh (:,1) double = zeros(size(x))
                soc (:,1) double = ones(size(x))
            end
            
            N = numel(time);
            if N < 2, return; end
            
            fprintf("3D animasyon başlatılıyor (%d kare)...\n", N);
            
            % Başlangıç konumu
            obj.updatePose(x(1), y(1), psi(1), v(1), w(1), energyWh(1), soc(1), time(1));
            drawnow;
            
            k = 1;
            while k <= N && isvalid(obj.Figure)
                if obj.IsPaused
                    pause(0.05);
                    continue;
                end
                
                obj.updatePose(x(k), y(k), psi(k), v(k), w(k), energyWh(k), soc(k), time(k));
                
                % Hız çarpanına göre kare atlama / bekleme
                stepJump = max(1, round(obj.PlaybackSpeed));
                dt = (time(min(k+stepJump, N)) - time(k)) / max(0.1, obj.PlaybackSpeed);
                
                if dt > 0.005
                    pause(min(0.05, dt));
                else
                    drawnow limitrate;
                end
                
                k = k + stepJump;
            end
            
            fprintf("3D animasyon tamamlandı.\n");
        end
    end
    
    methods (Access = private)
        function createScene(obj)
            % Pencere ve 3D ekseni hazırlar.
            obj.Figure = figure("Name", "LawnMowerRL 3D Engebeli Bahçe & Araç İzleyici", ...
                "NumberTitle", "off", "Color", [0.08 0.10 0.12], ...
                "Position", [80 60 1200 760]);
            
            obj.Axes = axes("Parent", obj.Figure, "Position", [0.02 0.05 0.96 0.90]);
            hold(obj.Axes, "on");
            axis(obj.Axes, "equal");
            grid(obj.Axes, "on");
            
            set(obj.Axes, "Color", [0.05 0.07 0.09], ...
                "XColor", [0.4 0.5 0.6], "YColor", [0.4 0.5 0.6], "ZColor", [0.4 0.5 0.6], ...
                "LineWidth", 1.0, "FontName", "Segoe UI", "FontSize", 9);
            
            xlabel(obj.Axes, "X [m]", "Color", [0.8 0.85 0.9]);
            ylabel(obj.Axes, "Y [m]", "Color", [0.8 0.85 0.9]);
            zlabel(obj.Axes, "Z [m]", "Color", [0.8 0.85 0.9]);
            
            xlim(obj.Axes, [-0.5, obj.Scenario.width + 0.5]);
            ylim(obj.Axes, [-0.5, obj.Scenario.height + 0.5]);
            
            maxZ = 3.0;
            if isfield(obj.Scenario, "elevationGrid")
                maxZ = max(maxZ, max(obj.Scenario.elevationGrid(:)) + 2.5);
            end
            zlim(obj.Axes, [-0.2, maxZ]);
            
            % Işıklandırma ve gölgelendirme
            camlight(obj.Axes, "headlight");
            light(obj.Axes, "Position", [obj.Scenario.width/2, obj.Scenario.height/2, 12], ...
                "Style", "local", "Color", [1.0 0.98 0.92]);
            lighting(obj.Axes, "gouraud");
            material(obj.Axes, "dull");
            
            % İz çizgisi
            obj.TrailLine = plot3(obj.Axes, NaN, NaN, NaN, "-", ...
                "Color", [1.0 0.75 0.1 0.75], "LineWidth", 2.5);
        end
        
        function buildGardenEnvironment(obj)
            % 3D Engebeli Çim Yüzeyi ve Gerçekçi Nesneleri inşa eder.
            rows = obj.Scenario.rows;
            cols = obj.Scenario.cols;
            
            % Çim hücre matrisi yüzeyi
            [X, Y] = meshgrid(linspace(0, obj.Scenario.width, cols+1), ...
                              linspace(0, obj.Scenario.height, rows+1));
            
            if isfield(obj.Scenario, "elevationGrid") && ~isempty(obj.Scenario.elevationGrid)
                Z = obj.Scenario.elevationGrid;
            else
                Z = zeros(size(X));
            end
            
            % Doku renk matrisi (Varsayılan: gür ve koyu çim yeşili)
            C = zeros(rows, cols, 3);
            for r = 1:rows
                for c = 1:cols
                    if obj.Scenario.obstacleMask(r,c)
                        C(r,c,:) = [0.28, 0.25, 0.20]; % Engel / Taş / Zemin rengi
                    else
                        noise = 0.04 * (rand() - 0.5);
                        C(r,c,:) = [0.18+noise, 0.56+noise, 0.15+noise];
                    end
                end
            end
            
            obj.GrassSurface = surf(obj.Axes, X, Y, Z, C, ...
                "FaceColor", "flat", "EdgeColor", [0.10 0.32 0.08], "EdgeAlpha", 0.3, ...
                "AmbientStrength", 0.6, "DiffuseStrength", 0.85);
            
            % 3D Çevre Çiti (Perimeter Fence)
            obj.buildPerimeterFence();
            
            % 3D Yapılar ve Engeller (Ev/Villa, Ağaçlar, Çiçeklik, Kulübe)
            obj.build3DStructures();
        end
        
        function buildPerimeterFence(obj)
            % Bahçe etrafına engebeli araziyi takip eden 3D ahşap çit ekler.
            W = obj.Scenario.width;
            H = obj.Scenario.height;
            fenceHeight = 0.35;
            postSpacing = 1.0;
            
            railColor = [0.70 0.58 0.42];
            
            % Sınır boyunca direkler ve korkuluklar
            for x = 0:postSpacing:W
                z0 = obj.getTerrainHeight(x, 0);
                zH = obj.getTerrainHeight(x, H);
                plot3(obj.Axes, [x x], [0 0], [z0 z0+fenceHeight], "-", "Color", [0.52 0.38 0.25], "LineWidth", 3.5);
                plot3(obj.Axes, [x x], [H H], [zH zH+fenceHeight], "-", "Color", [0.52 0.38 0.25], "LineWidth", 3.5);
            end
            for y = 0:postSpacing:H
                z0 = obj.getTerrainHeight(0, y);
                zW = obj.getTerrainHeight(W, y);
                plot3(obj.Axes, [0 0], [y y], [z0 z0+fenceHeight], "-", "Color", [0.52 0.38 0.25], "LineWidth", 3.5);
                plot3(obj.Axes, [W W], [y y], [zW zW+fenceHeight], "-", "Color", [0.52 0.38 0.25], "LineWidth", 3.5);
            end
        end
        
        function build3DStructures(obj)
            % Senaryo yapılarını (Ev, Ağaçlar, Çiçeklik, Kulübe) 3D olarak inşa eder.
            if ~isfield(obj.Scenario, "structures")
                return;
            end
            
            structs = obj.Scenario.structures;
            
            % 1. Bahçe Evi / Villa
            if isfield(structs, "houses") && ~isempty(structs.houses)
                for i = 1:size(structs.houses, 1)
                    h = structs.houses(i,:);
                    obj.create3DHouse(h(1), h(2), h(3), h(4), h(5));
                end
            end
            
            % 2. Ağaçlar
            if isfield(structs, "trees") && ~isempty(structs.trees)
                for i = 1:size(structs.trees, 1)
                    t = structs.trees(i,:);
                    obj.create3DTree(t(1), t(2), t(3), t(4));
                end
            end
            
            % 3. Çiçeklik
            if isfield(structs, "flowerbeds") && ~isempty(structs.flowerbeds)
                for i = 1:size(structs.flowerbeds, 1)
                    fb = structs.flowerbeds(i,:);
                    obj.create3DFlowerBed(fb(1), fb(2), fb(3), fb(4));
                end
            end
            
            % 4. Alet Kulübesi / Taş
            if isfield(structs, "sheds") && ~isempty(structs.sheds)
                for i = 1:size(structs.sheds, 1)
                    s = structs.sheds(i,:);
                    obj.create3DStoneShed(s(1), s(2), s(3), s(4), s(5));
                end
            end
        end
        
        function create3DHouse(obj, xMin, xMax, yMin, yMax, height)
            % Gerçekçi 3D Bahçe Evi (Duvarlar, Kırmızı Kiremit Çatı, Kapı ve Pencereler)
            zBase = obj.getTerrainHeight((xMin+xMax)/2, (yMin+yMax)/2);
            dx = (xMax - xMin);
            dy = (yMax - yMin);
            
            % Ana Duvarlar
            verts = [
                xMin yMin zBase; xMax yMin zBase; xMax yMax zBase; xMin yMax zBase; % Alt
                xMin yMin zBase+height; xMax yMin zBase+height; xMax yMax zBase+height; xMin yMax zBase+height % Üst
            ];
            faces = [
                1 2 3 4; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8
            ];
            patch(obj.Axes, 'Vertices', verts, 'Faces', faces, ...
                'FaceColor', [0.88 0.85 0.78], 'EdgeColor', [0.35 0.32 0.28], 'LineWidth', 1.5);
            
            % Kırma Kiremit Çatı (Hip Roof)
            roofZ = zBase + height;
            roofPeakZ = roofZ + 0.85;
            roofPeak = [(xMin+xMax)/2, (yMin+yMax)/2, roofPeakZ];
            roofVerts = [
                xMin-0.1 yMin-0.1 roofZ; xMax+0.1 yMin-0.1 roofZ; ...
                xMax+0.1 yMax+0.1 roofZ; xMin-0.1 yMax+0.1 roofZ; ...
                roofPeak
            ];
            roofFaces = [
                1 2 5; 2 3 5; 3 4 5; 4 1 5
            ];
            patch(obj.Axes, 'Vertices', roofVerts, 'Faces', roofFaces, ...
                'FaceColor', [0.75 0.24 0.18], 'EdgeColor', [0.45 0.15 0.10], 'LineWidth', 1.2);
            
            % Pencereler ve Kapı Detayı
            plot3(obj.Axes, [xMin+0.3 xMin+0.3], [yMin-0.01 yMin-0.01], [zBase+0.4 zBase+height-0.4], ...
                "-", "Color", [0.2 0.5 0.8], "LineWidth", 6);
            plot3(obj.Axes, [xMax-0.3 xMax-0.3], [yMin-0.01 yMin-0.01], [zBase+0.4 zBase+height-0.4], ...
                "-", "Color", [0.2 0.5 0.8], "LineWidth", 6);
        end
        
        function create3DTree(obj, x, y, trunkR, height)
            % 3D Silindirik ağaç gövdesi ve çok katmanlı yaprak tacı
            zBase = obj.getTerrainHeight(x, y);
            [cz, theta] = meshgrid([zBase, zBase + height*0.45], linspace(0, 2*pi, 16));
            cx = x + trunkR*0.35 * cos(theta);
            cy = y + trunkR*0.35 * sin(theta);
            surf(obj.Axes, cx, cy, cz, "FaceColor", [0.42 0.28 0.15], "EdgeColor", "none");
            
            % Yaprak tacı (Crown)
            [sx, sy, sz] = sphere(16);
            surf(obj.Axes, x + sx*trunkR*1.3, y + sy*trunkR*1.3, zBase + height*0.65 + sz*trunkR*0.9, ...
                "FaceColor", [0.15 0.52 0.12], "EdgeColor", "none", "SpecularStrength", 0.1);
            surf(obj.Axes, x + sx*trunkR*1.0, y + sy*trunkR*1.0, zBase + height*0.88 + sz*trunkR*0.75, ...
                "FaceColor", [0.22 0.62 0.18], "EdgeColor", "none", "SpecularStrength", 0.1);
        end
        
        function create3DFlowerBed(obj, xMin, xMax, yMin, yMax)
            % Renkli çiçek tarhı
            cx = (xMin + xMax)/2; cy = (yMin + yMax)/2;
            zBase = obj.getTerrainHeight(cx, cy);
            boxZ = zBase + 0.12;
            
            patch(obj.Axes, 'XData', [xMin xMax xMax xMin], ...
                            'YData', [yMin yMin yMax yMax], ...
                            'ZData', [boxZ boxZ boxZ boxZ], ...
                            'FaceColor', [0.32 0.20 0.12], 'EdgeColor', [0.55 0.38 0.22], 'LineWidth', 2);
            
            % Çiçek noktaları
            rng(42, "twister");
            colors = [0.95 0.2 0.2; 0.95 0.85 0.1; 0.7 0.2 0.8; 0.95 0.5 0.1];
            for i = 1:30
                fx = xMin + rand()*(xMax - xMin);
                fy = yMin + rand()*(yMax - yMin);
                fz = obj.getTerrainHeight(fx, fy) + 0.15;
                cIdx = randi(size(colors,1));
                plot3(obj.Axes, fx, fy, fz, "o", "MarkerSize", 6, ...
                    "MarkerFaceColor", colors(cIdx,:), "MarkerEdgeColor", "none");
            end
        end
        
        function create3DStoneShed(obj, xMin, xMax, yMin, yMax, height)
            % 3D Alet Kulübesi / Taş blok
            cx = (xMin + xMax)/2; cy = (yMin + yMax)/2;
            zBase = obj.getTerrainHeight(cx, cy);
            verts = [
                xMin yMin zBase; xMax yMin zBase; xMax yMax zBase; xMin yMax zBase;
                xMin yMin zBase+height; xMax yMin zBase+height; xMax yMax zBase+height; xMin yMax zBase+height
            ];
            faces = [
                1 2 3 4; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8
            ];
            patch(obj.Axes, 'Vertices', verts, 'Faces', faces, ...
                'FaceColor', [0.45 0.48 0.50], 'EdgeColor', [0.25 0.28 0.30], 'LineWidth', 1.5);
            
            % Çatı
            roofPeak = [cx, cy, zBase + height + 0.35];
            roofVerts = [
                xMin yMin zBase+height; xMax yMin zBase+height; ...
                xMax yMax zBase+height; xMin yMax zBase+height; ...
                roofPeak
            ];
            roofFaces = [1 2 5; 2 3 5; 3 4 5; 4 1 5];
            patch(obj.Axes, 'Vertices', roofVerts, 'Faces', roofFaces, ...
                'FaceColor', [0.65 0.22 0.18], 'EdgeColor', [0.40 0.12 0.10]);
        end
        
        function build3DRobot(obj)
            % Gerçekçi 3D LMR-680 Robot Montajını oluşturur.
            obj.RobotTransform = hgtransform("Parent", obj.Axes);
            
            L = obj.P.body.length;
            W = obj.P.body.width;
            H = obj.P.body.height;
            tw = obj.P.body.trackWidth;
            wb = obj.P.body.wheelbase;
            rw = obj.P.wheel.radius;
            ww = obj.P.wheel.width;
            
            % 1. Robot Şasisi (Aerodinamik Kırmızı/Metalik Ana Gövde)
            dx = L/2; dy = W/2; dz = H;
            bodyVerts = [
                -dx*0.9, -dy*0.9, 0; 
                 dx*0.85, -dy*0.85, 0; 
                 dx*0.95, 0, 0; 
                 dx*0.85, dy*0.85, 0; 
                -dx*0.9, dy*0.9, 0; ... % Alt (1-5)
                -dx*0.8, -dy*0.75, dz; 
                 dx*0.7, -dy*0.7, dz; 
                 dx*0.8, 0, dz*0.85; 
                 dx*0.7, dy*0.7, dz; 
                -dx*0.8, dy*0.75, dz   % Üst (6-10)
            ];
            % Alt ve Üst kapaklar (5'gen)
            patch("Parent", obj.RobotTransform, 'Vertices', bodyVerts, ...
                'Faces', [1 2 3 4 5; 6 7 8 9 10], ...
                'FaceColor', [0.85 0.12 0.10], 'EdgeColor', [0.35 0.05 0.05], ...
                'LineWidth', 1.5, 'SpecularStrength', 0.6, 'SpecularExponent', 15);
            % Yan paneller (4'gen)
            sideFaces = [
                1 2 7 6; 
                2 3 8 7; 
                3 4 9 8; 
                4 5 10 9; 
                5 1 6 10
            ];
            patch("Parent", obj.RobotTransform, 'Vertices', bodyVerts, ...
                'Faces', sideFaces, ...
                'FaceColor', [0.80 0.10 0.08], 'EdgeColor', [0.35 0.05 0.05], ...
                'LineWidth', 1.5, 'SpecularStrength', 0.6, 'SpecularExponent', 15);
            
            % 2. Siyah Koruma Tamponu ve Yan Etekler
            patch("Parent", obj.RobotTransform, ...
                'Vertices', [-dx -dy*0.95 -0.02; dx*0.9 -dy*0.95 -0.02; dx*0.9 dy*0.95 -0.02; -dx dy*0.95 -0.02; ...
                             -dx -dy*0.95 0.05; dx*0.9 -dy*0.95 0.05; dx*0.9 dy*0.95 0.05; -dx dy*0.95 0.05], ...
                'Faces', [1 2 3 4; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8], ...
                'FaceColor', [0.12 0.13 0.15], 'EdgeColor', "none");
            
            % 3. Ön LED Farlar (Headlights)
            plot3(obj.RobotTransform, [dx*0.85, dx*0.85], [-dy*0.5, dy*0.5], [dz*0.4, dz*0.4], ...
                "s", "MarkerSize", 9, "MarkerFaceColor", [0.9 0.95 1.0], "MarkerEdgeColor", [0.2 0.7 0.9]);
            
            % 4. RTK GNSS Anten Kubbesi
            [ax, ay, az] = cylinder([0.04 0.035 0], 12);
            surf(ax, ay, az*0.06 + dz, "Parent", obj.RobotTransform, ...
                "FaceColor", [0.96 0.96 0.96], "EdgeColor", [0.2 0.2 0.2]);
            
            % 5. Ön LiDAR / Ultrasonik Sensör
            [lx, ly, lz] = cylinder([0.03 0.03], 12);
            surf(lx + dx*0.6, ly, lz*0.05 + dz*0.9, "Parent", obj.RobotTransform, ...
                "FaceColor", [0.15 0.75 0.95], "EdgeColor", "none");
            
            % 6. Dönen Çift Kesici Bıçak / Disk Grubu
            obj.CutterTransform = hgtransform("Parent", obj.RobotTransform);
            discR = 0.105;
            theta = linspace(0, 2*pi, 24);
            for cy = [-0.095, 0.095]
                patch("Parent", obj.CutterTransform, ...
                    'XData', -0.03 + discR*cos(theta), ...
                    'YData', cy + discR*sin(theta), ...
                    'ZData', zeros(size(theta)) - 0.02, ...
                    'FaceColor', [0.95 0.75 0.18], 'EdgeColor', [0.65 0.45 0.05], 'FaceAlpha', 0.85);
                plot3(obj.CutterTransform, [-0.03-discR, -0.03+discR], [cy, cy], [-0.02, -0.02], ...
                    "-", "Color", [0.9 0.9 0.9], "LineWidth", 3);
            end
            
            % 7. 4 Adet Şasiye Paralel 3D Dişli Tekerlek
            % Daire X-Z düzleminde, genişlik Y ekseninde uzanır!
            wheelPos = [
                -wb/2, -tw/2;  % Sol arka
                 wb/2, -tw/2;  % Sol ön
                -wb/2,  tw/2;  % Sağ arka
                 wb/2,  tw/2   % Sağ ön
            ];
            
            thetaWheel = linspace(0, 2*pi, 16);
            [yMesh, thetaMesh] = meshgrid([-ww/2, ww/2], thetaWheel);
            xMesh = rw * cos(thetaMesh);
            zMesh = rw * sin(thetaMesh);
            
            for k = 1:4
                wT = hgtransform("Parent", obj.RobotTransform);
                set(wT, 'Matrix', makehgtform('translate', [wheelPos(k,1), wheelPos(k,2), 0]));
                
                % Tekerlek yerel dönüş transformu (Y ekseni etrafında)
                wSpinT = hgtransform("Parent", wT);
                obj.WheelTransforms(k) = wSpinT;
                
                % Tekerlek yüzeyi (Silindirik lastik sırtı)
                surf(xMesh, yMesh, zMesh, "Parent", wSpinT, ...
                    "FaceColor", [0.10 0.10 0.11], "EdgeColor", [0.25 0.25 0.25], ...
                    "SpecularStrength", 0.3);
                
                % Dış ve İç Jant Kapakları (X-Z Dairesel Diskleri)
                patch("Parent", wSpinT, ...
                    'XData', rw*cos(thetaWheel), ...
                    'YData', (ww/2)*ones(size(thetaWheel)), ...
                    'ZData', rw*sin(thetaWheel), ...
                    'FaceColor', [0.45 0.45 0.48], 'EdgeColor', [0.2 0.2 0.2]);
                patch("Parent", wSpinT, ...
                    'XData', rw*cos(thetaWheel), ...
                    'YData', (-ww/2)*ones(size(thetaWheel)), ...
                    'ZData', rw*sin(thetaWheel), ...
                    'FaceColor', [0.25 0.25 0.28], 'EdgeColor', [0.2 0.2 0.2]);
            end
        end
        
        function buildHUD(obj)
            % Ekran üzeri modern Telemetri / HUD ve Kontrol Paneli.
            obj.HudPanel = uipanel("Parent", obj.Figure, "Position", [0.02 0.74 0.36 0.24], ...
                "BackgroundColor", [0.06 0.08 0.10], "ForegroundColor", [0.3 0.6 0.9], ...
                "BorderType", "line", ...
                "Title", " LMR-680 CANLI TELEMETRİ & ARAZİ BİLGİSİ ", "FontWeight", "bold", ...
                "FontName", "Segoe UI", "FontSize", 10);
            
            obj.HudText = uicontrol("Parent", obj.HudPanel, "Style", "text", ...
                "Units", "normalized", "Position", [0.03 0.04 0.94 0.92], ...
                "HorizontalAlignment", "left", "BackgroundColor", [0.06 0.08 0.10], ...
                "ForegroundColor", [0.9 0.95 1.0], "FontName", "Consolas", "FontSize", 9.5, ...
                "String", sprintf("Yükleniyor..."));
            
            % Kontrol Butonları ve Kamera Seçici
            ctrlPanel = uipanel("Parent", obj.Figure, "Position", [0.64 0.02 0.34 0.06], ...
                "BackgroundColor", [0.08 0.10 0.12], "BorderType", "none");
            
            obj.FigControls.CamPopup = uicontrol("Parent", ctrlPanel, "Style", "popupmenu", ...
                "Units", "normalized", "Position", [0.02 0.15 0.38 0.7], ...
                "String", {"Takip (Chase)", "Kuşbakışı", "Serbest 3D", "Sensör (Ön)"}, ...
                "BackgroundColor", [0.15 0.18 0.22], "ForegroundColor", "w", "FontName", "Segoe UI", ...
                "Callback", @(src,~) obj.onCamChange(src.Value));
            
            uicontrol("Parent", ctrlPanel, "Style", "pushbutton", ...
                "Units", "normalized", "Position", [0.42 0.15 0.26 0.7], ...
                "String", "Duraklat", "BackgroundColor", [0.22 0.28 0.35], "ForegroundColor", "w", ...
                "FontName", "Segoe UI", "FontWeight", "bold", ...
                "Callback", @(src,~) obj.togglePause(src));
            
            uicontrol("Parent", ctrlPanel, "Style", "pushbutton", ...
                "Units", "normalized", "Position", [0.70 0.15 0.28 0.7], ...
                "String", "Hız: 2x", "BackgroundColor", [0.22 0.28 0.35], "ForegroundColor", "w", ...
                "FontName", "Segoe UI", "FontWeight", "bold", ...
                "Callback", @(src,~) obj.cycleSpeed(src));
        end
        
        function onCamChange(obj, val)
            modes = ["chase", "topdown", "orbit", "cockpit"];
            obj.CameraMode = modes(val);
        end
        
        function togglePause(obj, btn)
            obj.IsPaused = ~obj.IsPaused;
            if obj.IsPaused
                btn.String = "Oynat ▶";
                btn.BackgroundColor = [0.15 0.55 0.25];
            else
                btn.String = "Duraklat ❚❚";
                btn.BackgroundColor = [0.22 0.28 0.35];
            end
        end
        
        function cycleSpeed(obj, btn)
            speeds = [1.0, 2.0, 5.0, 10.0];
            idx = find(speeds == obj.PlaybackSpeed, 1);
            if isempty(idx) || idx == numel(speeds)
                obj.PlaybackSpeed = speeds(1);
            else
                obj.PlaybackSpeed = speeds(idx+1);
            end
            btn.String = sprintf("Hız: %.0fx", obj.PlaybackSpeed);
        end
        
        function z = getTerrainHeight(obj, x, y)
            % Anlık (x,y) dünya koordinatındaki arazi yüksekliğini döndürür.
            if isfield(obj.Scenario, "getElevation") && isa(obj.Scenario.getElevation, "function_handle")
                try
                    z = obj.Scenario.getElevation(x, y);
                    if isnan(z), z = 0; end
                    return;
                catch
                end
            end
            z = 0;
        end
        
        function [pitchAngle, rollAngle] = getTerrainAngles(obj, x, y, psi)
            % Arazi eğim gradyanından robotun gövde pitch ve roll açılarını hesaplar.
            delta = 0.15;
            zx1 = obj.getTerrainHeight(x + delta, y);
            zx0 = obj.getTerrainHeight(x - delta, y);
            zy1 = obj.getTerrainHeight(x, y + delta);
            zy0 = obj.getTerrainHeight(x, y - delta);
            
            slopeX = (zx1 - zx0) / (2 * delta);
            slopeY = (zy1 - zy0) / (2 * delta);
            
            % Boyuna (pitch) ve enine (roll) eğim
            longitudinalSlope = slopeX * cos(psi) + slopeY * sin(psi);
            lateralSlope = -slopeX * sin(psi) + slopeY * cos(psi);
            
            pitchAngle = -atan(longitudinalSlope);
            rollAngle = atan(lateralSlope);
        end
        
        function updateCuttingGrid(obj, x, y)
            % Robotun altındaki çim hücresini biçilmiş olarak işaretler ve yüzey rengini açar.
            c = clamp(ceil(x / obj.Scenario.cellSize), 1, obj.Scenario.cols);
            r = clamp(ceil(y / obj.Scenario.cellSize), 1, obj.Scenario.rows);
            
            cutRadius = max(1, round(obj.P.cutting.width / (2*obj.Scenario.cellSize)));
            rRange = max(1, r-cutRadius) : min(obj.Scenario.rows, r+cutRadius);
            cRange = max(1, c-cutRadius) : min(obj.Scenario.cols, c+cutRadius);
            
            changed = false;
            C = obj.GrassSurface.CData;
            
            for ri = rRange
                for ci = cRange
                    if ~obj.Scenario.obstacleMask(ri, ci) && obj.CutGrid(ri, ci) == 0
                        obj.CutGrid(ri, ci) = 1;
                        stripe = mod(ri, 2) * 0.05;
                        C(ri, ci, :) = [0.48+stripe, 0.82+stripe, 0.28+stripe];
                        changed = true;
                    end
                end
            end
            
            if changed
                obj.GrassSurface.CData = C;
            end
        end
        
        function updateCamera(obj, x, y, z, psi, pitch)
            % Seçili kamera moduna göre kamera bakış açısını ayarlar.
            switch obj.CameraMode
                case "chase"
                    camDist = 2.6;
                    camHeight = 1.8;
                    camX = x - camDist * cos(psi);
                    camY = y - camDist * sin(psi);
                    camZ = z + camHeight;
                    
                    targetX = x + 0.8 * cos(psi);
                    targetY = y + 0.8 * sin(psi);
                    targetZ = z + 0.2;
                    
                    campos(obj.Axes, [camX, camY, camZ]);
                    camtarget(obj.Axes, [targetX, targetY, targetZ]);
                    camva(obj.Axes, 45);
                    camup(obj.Axes, [0 0 1]);
                    
                case "topdown"
                    midX = obj.Scenario.width / 2;
                    midY = obj.Scenario.height / 2;
                    campos(obj.Axes, [midX, midY, max(obj.Scenario.width, obj.Scenario.height)*1.3]);
                    camtarget(obj.Axes, [midX, midY, 0]);
                    camva(obj.Axes, 50);
                    camup(obj.Axes, [0 1 0]);
                    
                case "cockpit"
                    camX = x + 0.35 * cos(psi);
                    camY = y + 0.35 * sin(psi);
                    camZ = z + 0.25;
                    
                    targetX = x + 3.0 * cos(psi);
                    targetY = y + 3.0 * sin(psi);
                    targetZ = z - sin(pitch)*2.0;
                    
                    campos(obj.Axes, [camX, camY, camZ]);
                    camtarget(obj.Axes, [targetX, targetY, targetZ]);
                    camva(obj.Axes, 65);
                    camup(obj.Axes, [0 0 1]);
                    
                case "orbit"
                    camtarget(obj.Axes, [x, y, z]);
            end
        end
        
        function updateHUD(obj, x, y, psi, v, w, pitchAngle, energyWh, soc, t)
            % HUD telemetri metnini günceller.
            cutCount = nnz(obj.CutGrid & obj.Scenario.freeMask);
            covRatio = 100 * (cutCount / max(1, obj.Scenario.freeCellCount));
            coveredArea = cutCount * (obj.Scenario.cellSize^2);
            slopePct = tan(-pitchAngle) * 100;
            
            slopePower = max(0, obj.P.body.mass * 9.81 * v * sin(-pitchAngle));
            powerW = (obj.P.energy.idlePower + obj.P.cutting.bladePower) + ...
                     obj.P.energy.linearCoeff*abs(v) + obj.P.energy.yawCoeff*abs(w) + slopePower;
            
            formatStr = ['Konum    : X=%.2f m | Y=%.2f m | Heading=%.1f°\n', ...
                         'Hız & Eğim: v=%.2f m/s | w=%.2f rad/s | Eğim=%% %.1f\n', ...
                         'Kapsama  : %%.1f (%.1f m² / %.1f m²)\n', ...
                         'Enerji   : %.1f Wh (Anlık Güç: %.0f W)\n', ...
                         'Batarya  : %%.1f SoC | Sim Süresi: %.1f s'];
            str = sprintf(formatStr, ...
                          x, y, rad2deg(psi), v, w, slopePct, covRatio, coveredArea, ...
                          obj.Scenario.freeCellCount*(obj.Scenario.cellSize^2), ...
                          energyWh, powerW, soc*100, t);
            
            set(obj.HudText, "String", str);
        end
    end
end

function val = clamp(val, low, high)
    val = min(max(val, low), high);
end
