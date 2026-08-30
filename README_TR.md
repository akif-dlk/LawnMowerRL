# Otonom Çim Biçme Robotu — MATLAB/Simulink + RL Başlangıç Projesi

Bu proje, Windows üzerinde çalışan bir çim biçme robotunun iki katmanlı dijital prototipidir:

1. **MATLAB planlama katmanı:** Bahçe haritası, engeller, klasik kapsama rotası, RL ortamı ve performans metrikleri.
2. **Simulink araç katmanı:** Diferansiyel/4WD skid-steer eşdeğer kinematik, tahrik gecikmesi, teker hızları ve enerji tüketimi.

İlk sürüm özellikle tez çalışmasına uygun tutulmuştur. RL ajanı yalnızca hedefe ulaşmayı değil, bahçeyi en az bindirme, dönüş, enerji ve çarpışmayla kapsamayı öğrenir.

## Mekanik başlangıç konsepti

| Özellik | Başlangıç değeri | Tasarım gerekçesi |
|---|---:|---|
| Gövde | 680 × 520 × 290 mm | RockMow/LUBA sınıfında kompakt dış mekân platformu |
| Sürüş | 4 teker, sol/sağ taraf eş hız kontrollü | Mekanikte AWD çekiş, modelde yalın diferansiyel sürüş |
| Dingil / iz genişliği | 420 / 460 mm | Dar bahçede çeviklik ve eğimde stabilite dengesi |
| Teker çapı | 220 mm | Çim ve küçük zemin bozuklukları için |
| Biçme tablası | Yüzer, çift disk, 400 mm toplam genişlik | Zemini takip etme ve yüksek kapsama |
| Biçme yüksekliği | 20–70 mm | Bahçe robotlarındaki yaygın aralık |
| Güvenlik | Ön bumper, disk muhafazası, kaldırma/eğim ve acil durdurma girdileri | Fiziksel prototip fazında zorunlu güvenlik zinciri |

Bu modelde dört tekerin sol çifti ve sağ çifti sanal olarak birer tahrik kanalıdır. Sonraki fazda her teker için kayma, süspansiyon ve eğim dinamiği eklenebilir.

## Gereksinimler

- Windows 10/11
- MATLAB R2024b veya daha yeni önerilir
- Simulink
- Reinforcement Learning Toolbox
- Deep Learning Toolbox
- İsteğe bağlı: Parallel Computing Toolbox (eğitimi hızlandırmak için)

## İlk çalıştırma

ZIP'i bir klasöre çıkarın, MATLAB'da o klasörü açın ve çalıştırın:

```matlab
run_project
```

Ayrıntılı Windows adımları: `docs/WINDOWS_KURULUM.md`.

Bu komut:

- klasörleri MATLAB yoluna ekler,
- gereksinimleri kontrol eder,
- robot mekanik konseptini ve bahçeyi çizer,
- `models/LawnMowerPlant.slx` dosyasını üretir,
- engelleri dolaşan klasik serpantin rotasını Simulink'te çalıştırır,
- RL ortamını oluşturup doğrular.

## RL eğitimi

Önce hızlı bir deneme:

```matlab
setupProject;
P = robotParameters("quick");
[agent, stats] = trainCoverageDQN(P);
result = evaluateCoverageAgent(agent, P, [], true);
compareCoverageMethods(result, P);
```

Daha uzun tez koşusu:

```matlab
P = robotParameters("thesis");
[agent, stats] = trainCoverageDQN(P);
```

Eğitim çıktıları `results/` içine kaydedilir. `quick` profil kodun ve ortamın çalıştığını görmek içindir; bilimsel sonuç olarak kullanılmamalıdır.

## Ana komutlar

| Komut | İşlev |
|---|---|
| `run_project` | Baştan sona başlangıç demosu |
| `showMechanicalConcept(robotParameters)` | Üstten mekanik yerleşim |
| `buildLawnMowerSimulinkModel` | Simulink modelini yeniden üretir |
| `runBaselineSimulation` | Engelli serpantin referans rotasını çalıştırır |
| `createCoverageEnvironment` | RL kapsama ortamını oluşturur |
| `trainCoverageDQN` | DQN ajanını eğitir ve kaydeder |
| `evaluateCoverageAgent` | Ajanın kapsama rotasını ve metriklerini çıkarır |
| `runRLInSimulink` | Eğitilmiş ajanın rotasını Simulink araç modelinde çalıştırır |
| `compareCoverageMethods` | RL ile klasik rotayı karşılaştırır |
| `runSmokeTests` | RL eğitimi yapmadan temel mantık testleri |

## RL formülasyonu

Durum; biçilen hücreler, engel haritası, robot hücresi, yönü ve kapsama oranından oluşur. Aksiyonlar kuzey/doğu/güney/batı komşu hücrelerine geçiştir.

Toplam ödülün başlangıç biçimi:

\[
r_t = r_{yeni\ alan} - c_{bindirme} - c_{donus} - c_{enerji} - c_{carpisma} + r_{tamamlama}
\]

Bu ayrıştırma tezde ablation çalışmasına uygundur: her ceza terimi kapatılarak yol uzunluğu, süre, enerji ve kapsama üzerindeki etkisi ölçülebilir.

## Proje sınırı

Bu paket ilk çalışan sayısal prototiptir; henüz ayrıntılı Simscape Multibody mekanik modeli, lastik-toprak kayması, RTK/IMU gürültüsü, kamera/LiDAR algısı ve ROS 2 haberleşmesi içermez. Bunlar `docs/TEZ_YOL_HARITASI.md` içindeki sırayla eklenmelidir.
