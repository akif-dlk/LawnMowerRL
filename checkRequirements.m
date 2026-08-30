function report = checkRequirements()
%CHECKREQUIREMENTS Kurulu MATLAB ürünlerini ve önerilen sürümü kontrol eder.

products = string({ver.Name});
report.MATLAB = any(products == "MATLAB");
report.Simulink = any(products == "Simulink");
report.ReinforcementLearning = any(products == "Reinforcement Learning Toolbox");
report.DeepLearning = any(products == "Deep Learning Toolbox");
report.ParallelComputing = any(products == "Parallel Computing Toolbox");

fprintf("\nÜrün kontrolü\n");
fprintf("  MATLAB:                         %s\n", tfText(report.MATLAB));
fprintf("  Simulink:                       %s\n", tfText(report.Simulink));
fprintf("  Reinforcement Learning Toolbox: %s\n", tfText(report.ReinforcementLearning));
fprintf("  Deep Learning Toolbox:          %s\n", tfText(report.DeepLearning));
fprintf("  Parallel Computing (opsiyonel): %s\n\n", tfText(report.ParallelComputing));

assert(report.MATLAB, "MATLAB kurulumu algılanamadı.");
assert(report.Simulink, "Bu proje için Simulink gereklidir.");

if verLessThan("matlab", "24.2")
    warning("Proje R2024b+ için hazırlanmıştır. Eski sürümde ad-değer sözdizimi veya RL seçenekleri uyarlama isteyebilir.");
end
if ~(report.ReinforcementLearning && report.DeepLearning)
    warning("RL eğitimi için Reinforcement Learning Toolbox ve Deep Learning Toolbox gereklidir.");
end
end

function txt = tfText(value)
if value
    txt = "VAR";
else
    txt = "YOK";
end
end

