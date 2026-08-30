%% LawnMowerRL 3D Canlı Görselleştirme ve Test Demosu
% Bu script, LMR-680 otonom çim biçme robotunun 3D bahçe ortamında
% Simulink simülasyonunu koşturur ve etkileşimli canlı animasyon penceresini açar.

projectRoot = fileparts(mfilename("fullpath"));
cd(projectRoot);
setupProject;

P = robotParameters("quick");
scenario = createGardenScenario(P, "demo");

fprintf("====================================================\n");
fprintf("   LawnMowerRL 3D Canlı Bahçe & Simulink Simülasyonu \n");
fprintf("====================================================\n");
fprintf("1. Bahçe senaryosu hazırlanıyor (%s, %.1f x %.1f m)\n", ...
    scenario.name, scenario.width, scenario.height);
fprintf("2. Klasik boustrophedon rotası ve Simulink tahrik modeli çalıştırılıyor...\n");

% Simulink simülasyonunu koştur
baselineResult = runBaselineSimulation(P, scenario, false);

fprintf("3. 3D Canlı Takip Arayüzü açılıyor...\n");
fprintf("   - Kamera modunu değiştirebilir (Chase / Kuşbakışı / Serbest 3D / Sensör)\n");
fprintf("   - Hızı ayarlayabilir veya duraklatabilirsiniz.\n\n");

viewer = animateLawnMower3D(baselineResult, scenario, P, "chase");

fprintf("3D Canlı Gösterim Aktif!\n");
