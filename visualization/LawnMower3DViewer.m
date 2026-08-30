classdef LawnMower3DViewer < handle
    %LAWNMOWER3DVIEWER Otonom çim biçme robotu için 3D ve canlı görselleştirici.
    %
    % Özellikler:
    %   - 3D Robot Montajı: Gövde, 4 tekerlek, dönen kesici diskler, RTK ve farlar
    %   - 3D Bahçe ve Engeller: Dinamik çim biçme izi, 3D ağaçlar, çiçeklikler ve çit
    %   - Çoklu Kamera: Chase Cam (Takip), Top-Down (Kuşbakışı), Orbit (Serbest 3D), Cockpit (Sensör)
    %   - Canlı Telemetri ve HUD: Hız, kapsama %, batarya SoC %, güç ve enerji
    %   - Etkileşimli Kontrol: Oynat, duraklat, hız çarpanı, kamera değiştirme

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
        MaxTrailLength = 500
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
            % Robotun anlık konum, yönelim ve telemetri durumunu günceller.
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
            
            z = obj.P.wheel.radius; % Z yüksekliği
            
            % 1. Robot ana transformasyon matrisini güncelle
            M = makehgtform('translate', [x, y, z], 'zrotate', psi);
            set(obj.RobotTransform, 'Matrix', M);
            
            % 2. Kesici disklerin yüksek hızlı dönüş animasyonu (Biçme aktifken)
            if obj.IsMowing
                obj.BladeAngle = mod(obj.BladeAngle + 0.45, 2*pi);
                set(obj.CutterTransform, 'Matrix', makehgtform('zrotate', obj.BladeAngle));
            end
            
            % 3. Tekerleklerin dönüşü
            obj.WheelAngle = mod(obj.WheelAngle + (v * 0.1 / obj.P.wheel.radius), 2*pi);
            for k = 1:numel(obj.WheelTransforms)
                if isvalid(obj.WheelTransforms(k))
                    % Tekerlek yerel dönüşü (Y ekseninde)
                    set(obj.WheelTransforms(k), 'Matrix', makehgtform('yrotate', obj.WheelAngle));
                end
            end
            
            % 4. Çim biçme izi ve kapsama matrisini güncelle
            obj.updateCuttingGrid(x, y);
            
            % 5. Rota iz çizgisi
            obj.TrailPoints(end+1,:) = [x, y, z*0.4];
            if size(obj.TrailPoints, 1) > obj.MaxTrailLength
                obj.TrailPoints(1,:) = [];
            end
            set(obj.TrailLine, 'XData', obj.TrailPoints(:,1), ...
                              'YData', obj.TrailPoints(:,2), ...
                              'ZData', obj.TrailPoints(:,3));
            
            % 6. Kamera takibi
            obj.updateCamera(x, y, z, psi);
            
            % 7. HUD Telemetri göstergeleri
            obj.updateHUD(x, y, psi, v, w, energyWh, soc, t);
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
            obj.Figure = figure("Name", "LawnMowerRL 3D Gerçek Zamanlı Bahçe & Araç İzleyici", ...
                "NumberTitle", "off", "Color", [0.08 0.10 0.12], ...
                "Position", [100 80 1150 720]);
            
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
            zlim(obj.Axes, [-0.1, 2.5]);
            
            % Işıklandırma ve gölgelendirme
            camlight(obj.Axes, "headlight");
            light(obj.Axes, "Position", [obj.Scenario.width/2, obj.Scenario.height/2, 10], "Style", "local", "Color", [1.0 0.98 0.92]);
            lighting(obj.Axes, "gouraud");
            material(obj.Axes, "dull");
            
            % İz çizgisi
            obj.TrailLine = plot3(obj.Axes, NaN, NaN, NaN, "-", ...
                "Color", [1.0 0.75 0.1 0.7], "LineWidth", 2.5);
        end
        
        function buildGardenEnvironment(obj)
            % 3D Çim yüzeyi, biçilmemiş/biçilmiş renk dokusu ve engelleri inşa eder.
            rows = obj.Scenario.rows;
            cols = obj.Scenario.cols;
            
            % Çim hücre matrisi yüzeyi
            [X, Y] = meshgrid(linspace(0, obj.Scenario.width, cols+1), ...
                              linspace(0, obj.Scenario.height, rows+1));
            Z = zeros(size(X));
            
            % Doku renk matrisi (Varsayılan: gür ve koyu çim yeşili)
            C = zeros(rows, cols, 3);
            for r = 1:rows
                for c = 1:cols
                    if obj.Scenario.obstacleMask(r,c)
                        C(r,c,:) = [0.25, 0.22, 0.18]; % Engel / Toprak / Taş rengi
                    else
                        % Çim varyasyonu
                        noise = 0.04 * (rand() - 0.5);
                        C(r,c,:) = [0.18+noise, 0.58+noise, 0.16+noise];
                    end
                end
            end
            
            obj.GrassSurface = surf(obj.Axes, X, Y, Z, C, ...
                "FaceColor", "flat", "EdgeColor", [0.12 0.35 0.10], "EdgeAlpha", 0.3, ...
                "AmbientStrength", 0.6, "DiffuseStrength", 0.8);
            
            % 3D Çevre Çiti (Perimeter Fence)
            obj.buildPerimeterFence();
            
            % 3D Engeller (Ağaçlar, Çiçeklikler, Yapılar)
            obj.build3DObstacles();
        end
        
        function buildPerimeterFence(obj)
            % Bahçe etrafına şık 3D ahşap çit sütunları ekler.
            W = obj.Scenario.width;
            H = obj.Scenario.height;
            fenceHeight = 0.35;
            postSpacing = 1.0;
            
            % Çit rayları (korkuluklar)
            railColor = [0.72 0.60 0.45];
            plot3(obj.Axes, [0 W W 0 0], [0 0 H H 0], [fenceHeight*0.5 fenceHeight*0.5 fenceHeight*0.5 fenceHeight*0.5 fenceHeight*0.5], ...
                "-", "Color", railColor, "LineWidth", 3);
            plot3(obj.Axes, [0 W W 0 0], [0 0 H H 0], [fenceHeight*0.9 fenceHeight*0.9 fenceHeight*0.9 fenceHeight*0.9 fenceHeight*0.9], ...
                "-", "Color", railColor, "LineWidth", 3);
            
            % Direkler (Sütunlar)
            for x = 0:postSpacing:W
                plot3(obj.Axes, [x x], [0 0], [0 fenceHeight], "-", "Color", [0.55 0.42 0.28], "LineWidth", 4);
                plot3(obj.Axes, [x x], [H H], [0 fenceHeight], "-", "Color", [0.55 0.42 0.28], "LineWidth", 4);
            end
            for y = 0:postSpacing:H
                plot3(obj.Axes, [0 0], [y y], [0 fenceHeight], "-", "Color", [0.55 0.42 0.28], "LineWidth", 4);
                plot3(obj.Axes, [W W], [y y], [0 fenceHeight], "-", "Color", [0.55 0.42 0.28], "LineWidth", 4);
            end
        end
        
        function build3DObstacles(obj)
            % Senaryodaki engelleri 3D ağaçlar, çiçeklikler veya taş bloklar olarak çizer.
            switch obj.Scenario.name
                case "demo"
                    % Ağaç Adası: Ağaç gövdesi ve yaprak tacı
                    obj.create3DTree(10 * obj.Scenario.cellSize, 7 * obj.Scenario.cellSize, 0.8, 1.8);
                    
                    % Çiçeklik (Çiçek öbeği)
                    obj.create3DFlowerBed(22.5 * obj.Scenario.cellSize, 14.5 * obj.Scenario.cellSize, 1.6, 1.6);
                    
                    % Taş/Kulübe engeli
                    obj.create3DStoneShed(26 * obj.Scenario.cellSize, 5 * obj.Scenario.cellSize, 1.2, 1.2, 0.7);
                    
                otherwise
                    % Genel engeller için 3D yükseltilmiş bloklar
                    [obsRows, obsCols] = find(obj.Scenario.obstacleMask);
                    if numel(obsRows) > 0
                        step = max(1, round(numel(obsRows) / 12));
                        for k = 1:step:numel(obsRows)
                            cx = (obsCols(k) - 0.5) * obj.Scenario.cellSize;
                            cy = (obsRows(k) - 0.5) * obj.Scenario.cellSize;
                            obj.create3DStoneShed(cx, cy, obj.Scenario.cellSize*0.9, obj.Scenario.cellSize*0.9, 0.4);
                        end
                    end
            end
        end
        
        function create3DTree(obj, x, y, trunkR, height)
            % 3D Silindirik ağaç gövdesi ve küresel yaprak tacı
            [cz, theta] = meshgrid([0, height*0.45], linspace(0, 2*pi, 16));
            cx = x + trunkR*0.35 * cos(theta);
            cy = y + trunkR*0.35 * sin(theta);
            surf(obj.Axes, cx, cy, cz, "FaceColor", [0.42 0.28 0.15], "EdgeColor", "none", "AmbientStrength", 0.4);
            
            % Yaprak tacı (Crown - Yeşillik katmanları)
            [sx, sy, sz] = sphere(16);
            surf(obj.Axes, x + sx*trunkR*1.3, y + sy*trunkR*1.3, height*0.65 + sz*trunkR*0.9, ...
                "FaceColor", [0.15 0.52 0.12], "EdgeColor", "none", "SpecularStrength", 0.1);
            surf(obj.Axes, x + sx*trunkR*1.0, y + sy*trunkR*1.0, height*0.88 + sz*trunkR*0.75, ...
                "FaceColor", [0.22 0.62 0.18], "EdgeColor", "none", "SpecularStrength", 0.1);
        end
        
        function create3DFlowerBed(obj, x, y, width, height)
            % Renkli çiçek tarhı
            boxZ = 0.12;
            patch(obj.Axes, 'XData', [x-width/2 x+width/2 x+width/2 x-width/2], ...
                            'YData', [y-height/2 y-height/2 y+height/2 y+height/2], ...
                            'ZData', [boxZ boxZ boxZ boxZ], ...
                            'FaceColor', [0.32 0.20 0.12], 'EdgeColor', [0.55 0.38 0.22], 'LineWidth', 2);
            
            % Çiçek noktaları
            rng(42, "twister");
            colors = [0.95 0.2 0.2; 0.95 0.85 0.1; 0.7 0.2 0.8; 0.95 0.5 0.1];
            for i = 1:25
                fx = x + (rand()-0.5)*width*0.8;
                fy = y + (rand()-0.5)*height*0.8;
                cIdx = randi(size(colors,1));
                plot3(obj.Axes, fx, fy, boxZ+0.03, "o", "MarkerSize", 6, ...
                    "MarkerFaceColor", colors(cIdx,:), "MarkerEdgeColor", "none");
            end
        end
        
        function create3DStoneShed(obj, x, y, width, length, height)
            % 3D Yapı / Taş blok
            dx = width/2; dy = length/2;
            verts = [
                x-dx y-dy 0; x+dx y-dy 0; x+dx y+dy 0; x-dx y+dy 0; % Alt
                x-dx y-dy height; x+dx y-dy height; x+dx y+dy height; x-dx y+dy height % Üst
            ];
            faces = [
                1 2 3 4; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8
            ];
            patch(obj.Axes, 'Vertices', verts, 'Faces', faces, ...
                'FaceColor', [0.45 0.48 0.50], 'EdgeColor', [0.25 0.28 0.30], 'LineWidth', 1.5);
            
            % Çatı piramidi
            roofVerts = [
                x-dx y-dy height; x+dx y-dy height; x+dx y+dy height; x-dx y+dy height;
                x y height+0.25
            ];
            roofFaces = [
                1 2 5; 2 3 5; 3 4 5; 4 1 5
            ];
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
                % Bıçak uçları
                plot3(obj.CutterTransform, [-0.03-discR, -0.03+discR], [cy, cy], [-0.02, -0.02], ...
                    "-", "Color", [0.9 0.9 0.9], "LineWidth", 3);
            end
            
            % 7. 4 Adet 3D Dişli Tekerlek
            wheelPos = [
                -wb/2, -tw/2;  % Sol arka
                 wb/2, -tw/2;  % Sol ön
                -wb/2,  tw/2;  % Sağ arka
                 wb/2,  tw/2   % Sağ ön
            ];
            
            for k = 1:4
                wT = hgtransform("Parent", obj.RobotTransform);
                set(wT, 'Matrix', makehgtform('translate', [wheelPos(k,1), wheelPos(k,2), 0]));
                
                % Tekerlek yerel dönüş transformu
                wSpinT = hgtransform("Parent", wT);
                obj.WheelTransforms(k) = wSpinT;
                
                % 3D Silindirik Tekerlek Gövdesi
                [wy, wz, wx] = cylinder(rw, 14);
                wx = (wx - 0.5) * ww;
                surf(wx, wy, wz, "Parent", wSpinT, ...
                    "FaceColor", [0.10 0.10 0.11], "EdgeColor", [0.25 0.25 0.25], "SpecularStrength", 0.3);
                % Jant Kapağı
                patch("Parent", wSpinT, 'XData', [ww/2, ww/2]*1.01, 'YData', [0 0], 'ZData', [0 0], ...
                    "Marker", "o", "MarkerSize", 5, "MarkerFaceColor", [0.8 0.8 0.8], "MarkerEdgeColor", "none");
            end
        end
        
        function buildHUD(obj)
            % Ekran üzeri modern Telemetri / HUD ve Kontrol Paneli.
            obj.HudPanel = uipanel("Parent", obj.Figure, "Position", [0.02 0.76 0.34 0.22], ...
                "BackgroundColor", [0.06 0.08 0.10], "ForegroundColor", [0.3 0.6 0.9], ...
                "BorderType", "line", ...
                "Title", " LMR-680 CANLI TELEMETRİ ", "FontWeight", "bold", "FontName", "Segoe UI", ...
                "FontSize", 10);
            
            obj.HudText = uicontrol("Parent", obj.HudPanel, "Style", "text", ...
                "Units", "normalized", "Position", [0.03 0.05 0.94 0.90], ...
                "HorizontalAlignment", "left", "BackgroundColor", [0.06 0.08 0.10], ...
                "ForegroundColor", [0.9 0.95 1.0], "FontName", "Consolas", "FontSize", 10, ...
                "String", sprintf("Hız: 0.00 m/s | Yaw: 0.0°/s\nKapsama: 0.0%% (0.0 m²)\nEnerji: 0.0 Wh | SoC: 100.0%%\nZaman: 0.0 s"));
            
            % Kontrol Butonları ve Kamera Seçici
            ctrlPanel = uipanel("Parent", obj.Figure, "Position", [0.66 0.02 0.32 0.06], ...
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
        
        function updateCuttingGrid(obj, x, y)
            % Robotun altındaki çim hücresini biçilmiş olarak işaretler ve yüzey rengini açar.
            c = clamp(ceil(x / obj.Scenario.cellSize), 1, obj.Scenario.cols);
            r = clamp(ceil(y / obj.Scenario.cellSize), 1, obj.Scenario.rows);
            
            % Kesme genişliği içindeki komşu hücreleri de kontrol et
            cutRadius = max(1, round(obj.P.cutting.width / (2*obj.Scenario.cellSize)));
            rRange = max(1, r-cutRadius) : min(obj.Scenario.rows, r+cutRadius);
            cRange = max(1, c-cutRadius) : min(obj.Scenario.cols, c+cutRadius);
            
            changed = false;
            C = obj.GrassSurface.CData;
            
            for ri = rRange
                for ci = cRange
                    if ~obj.Scenario.obstacleMask(ri, ci) && obj.CutGrid(ri, ci) == 0
                        obj.CutGrid(ri, ci) = 1;
                        % Biçilmiş çim: Açık parlak çim şeridi tonu
                        stripe = mod(ri, 2) * 0.05;
                        C(ri, ci, :) = [0.48+stripe, 0.80+stripe, 0.28+stripe];
                        changed = true;
                    end
                end
            end
            
            if changed
                obj.GrassSurface.CData = C;
            end
        end
        
        function updateCamera(obj, x, y, z, psi)
            % Seçili kamera moduna göre kamera bakış açısını pürüzsüz ayarlar.
            switch obj.CameraMode
                case "chase"
                    % Robotun arkasından takip (Chase Cam)
                    camDist = 2.4;
                    camHeight = 1.6;
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
                    % Kuşbakışı (Top-Down Garden)
                    midX = obj.Scenario.width / 2;
                    midY = obj.Scenario.height / 2;
                    campos(obj.Axes, [midX, midY, max(obj.Scenario.width, obj.Scenario.height)*1.2]);
                    camtarget(obj.Axes, [midX, midY, 0]);
                    camva(obj.Axes, 50);
                    camup(obj.Axes, [0 1 0]);
                    
                case "cockpit"
                    % Sensör / Ön Tampon Kamerası
                    camX = x + 0.35 * cos(psi);
                    camY = y + 0.35 * sin(psi);
                    camZ = z + 0.25;
                    
                    targetX = x + 3.0 * cos(psi);
                    targetY = y + 3.0 * sin(psi);
                    targetZ = z;
                    
                    campos(obj.Axes, [camX, camY, camZ]);
                    camtarget(obj.Axes, [targetX, targetY, targetZ]);
                    camva(obj.Axes, 65);
                    camup(obj.Axes, [0 0 1]);
                    
                case "orbit"
                    % Serbest Orbit: Kullanıcı fare kontrolüne izin verilir, sadece hedef odaklanır
                    camtarget(obj.Axes, [x, y, z]);
            end
        end
        
        function updateHUD(obj, x, y, psi, v, w, energyWh, soc, t)
            % HUD telemetri metnini günceller.
            cutCount = nnz(obj.CutGrid & obj.Scenario.freeMask);
            covRatio = 100 * (cutCount / max(1, obj.Scenario.freeCellCount));
            coveredArea = cutCount * (obj.Scenario.cellSize^2);
            powerW = (obj.P.energy.idlePower + obj.P.cutting.bladePower) + ...
                     obj.P.energy.linearCoeff*abs(v) + obj.P.energy.yawCoeff*abs(w);
            
            formatStr = ['Pozisyon : X=%.2f m | Y=%.2f m | Heading=%.1f°\n', ...
                         'Hız      : v=%.2f m/s | yaw rate=%.2f rad/s\n', ...
                         'Kapsama  : %%.1f (%.1f m² / %.1f m²)\n', ...
                         'Enerji   : %.1f Wh (Anlık Güç: %.0f W)\n', ...
                         'Batarya  : %%.1f SoC | Sim Süresi: %.1f s'];
            str = sprintf(formatStr, ...
                          x, y, rad2deg(psi), v, w, covRatio, coveredArea, ...
                          obj.Scenario.freeCellCount*(obj.Scenario.cellSize^2), ...
                          energyWh, powerW, soc*100, t);
            
            set(obj.HudText, "String", str);
        end
    end
end

function val = clamp(val, low, high)
    val = min(max(val, low), high);
end
