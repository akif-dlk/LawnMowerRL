# Windows Kurulumu

1. ZIP dosyasını kısa ve boşluksuz bir yola çıkarın; örnek: `C:\MATLABProjects\LawnMowerRL`.
2. MATLAB R2024b+ kurulumunda Simulink, Reinforcement Learning Toolbox ve Deep Learning Toolbox ürünlerini seçin.
3. MATLAB'ı açın ve **Current Folder** alanından proje klasörüne geçin.
4. Command Window'da çalıştırın:

```matlab
run_project
```

5. Yalnızca hızlı yapısal kontrol için:

```matlab
setupProject;
runSmokeTests(true)
```

6. İlk kısa eğitim için:

```matlab
P = robotParameters("quick");
[agent,stats] = trainCoverageDQN(P);
result = runRLInSimulink(agent,P);
compareCoverageMethods(result,P);
```

## Sık karşılaşılan durumlar

- `Undefined function robotParameters`: Önce `setupProject` çalıştırın veya Current Folder'ı proje köküne alın.
- `rlFunctionEnv not found`: Reinforcement Learning Toolbox kurulu değildir.
- Paralel havuz hatası: `P.rl.useParallel = false;` yapın. Hızlı profil zaten seri çalışır.
- Model eski MATLAB sürümünde açılmıyor: `buildLawnMowerSimulinkModel(P,false)` ile o sürümde yeniden üretmeyi deneyin; proje R2024b+ hedefler.
- Eğitim uzun sürüyor: Önce `quick` profil kullanın. 30×20 harita tez deneyi için büyüktür; algoritma doğrulaması sırasında satır/sütunları küçültmek normaldir.
