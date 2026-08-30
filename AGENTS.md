# AGENTS.md — LawnMowerRL (Otonom Çim Biçme Robotu, MATLAB/Simulink + RL)

Bu dosya bu repo kökünde durur. Antigravity / Gemini agent modunda çalışan
her ajan, göreve başlamadan önce bu dosyayı okumuş kabul edilir. Buradaki
kurallar kullanıcının (Eva) doğrudan talimatlarıyla çelişirse, kullanıcının
o anki mesajı önceliklidir — ama sessizce çelişkiyi yok saymak yerine
kullanıcıya kısaca belirt.

## Proje nedir

İki katmanlı bir dijital prototip:
1. **MATLAB planlama katmanı** (`planning/`, `scenarios/`, `config/`) —
   bahçe haritası, klasik (boustrophedon/serpantin) kapsama rotası, DQN
   tabanlı RL kapsama ajanı, performans metrikleri.
2. **Simulink araç katmanı** (`models/`, `simulation/`) — 4 tekerli
   skid-steer eşdeğer kinematik, tahrik gecikmesi, enerji tüketimi.

Amaç: RL ajanının klasik serpantin rotasına göre bindirme, dönüş, enerji
ve çarpışma açısından daha iyi kapsama sağlaması (tez çalışması).

## Klasör haritası

| Klasör | İçerik |
|---|---|
| `config/robotParameters.m` | Tüm parametre profilleri (`"quick"`, `"thesis"`) — robot boyutları, ödül ağırlıkları, eğitim hiperparametreleri burada |
| `scenarios/` | Bahçe/engel haritası üretimi (`createGardenScenario`), hücre↔dünya koordinat dönüşümü |
| `planning/` | RL ortamı (`createCoverageEnvironment`, `stepCoverageEnv`, `resetCoverageEnv`), DQN eğitimi (`trainCoverageDQN`), değerlendirme, klasik rota baseline'ı, karşılaştırma |
| `models/buildLawnMowerSimulinkModel.m` | `.slx` model üretici (kod ile Simulink modeli inşa ediyor) |
| `simulation/` | Baseline/RL rotasını Simulink'te koşturma, path→komut dönüşümü |
| `tests/runSmokeTests.m` | **Eğitim yapmadan** çekirdek mantığı doğrulayan hızlı test |
| `results/` | Eğitim çıktıları buraya kaydedilir (büyük/binary dosyalar — bkz. Git kuralları) |
| `docs/TEZ_YOL_HARITASI.md` | Sıradaki adımlar (Simscape Multibody, lastik-toprak kayması, RTK/IMU gürültüsü, kamera/LiDAR, ROS 2) — henüz bu repoda yok |

## Ortam ve çalıştırma

- MATLAB R2024b+, Simulink, Reinforcement Learning Toolbox, Deep Learning
  Toolbox gerekir. `checkRequirements.m` bunu kontrol eder.
- Ajan (agent) MATLAB'ı **komut satırından batch modda** çalıştırabilir:
  ```
  matlab -batch "run_project"
  matlab -batch "setupProject; runSmokeTests"
  matlab -batch "setupProject; P = robotParameters('quick'); [agent,stats] = trainCoverageDQN(P); evaluateCoverageAgent(agent,P,[],true);"
  ```
- **Her kod değişikliğinden sonra önce `runSmokeTests` çalıştırılır.**
  Bu, eğitim yapmadan (saniyeler içinde) temel mantığı doğrular: senaryo
  kurulumu, klasik rota geçerliliği, RL ortamı gözlem/ödül boyutları,
  path→komut dönüşümü. Eğitim gerektiren değişikliklerde ayrıca
  `robotParameters("quick")` ile kısa bir deneme koşusu yapılır —
  `"thesis"` profili (uzun koşu) sadece açıkça istenirse çalıştırılır,
  çünkü uzun sürer ve kaynak tüketir.
- Simulink modeli gerektiren bir değişiklik varsa `buildLawnMowerSimulinkModel`
  yeniden çalıştırılıp `.slx` güncellenir; agent bunu otomatik yapabilir
  ama üretilen `.slx`'i commit etmeden önce kullanıcıya haber verir (bkz.
  Git kuralları — binary model dosyaları dikkatli yönetilir).

## Kod stili ve kurallar

- Yorumlar ve fonksiyon açıklamaları **Türkçe** (mevcut kod tabanıyla
  tutarlı kalsın).
- `arguments` bloklarıyla tip/varsayılan değer kontrolü kullanılıyor
  (`runSmokeTests.m`'deki gibi) — yeni fonksiyonlar da bu deseni izlesin.
- Parametre değişiklikleri (`robotParameters.m`) `"quick"` ve `"thesis"`
  profillerinin ikisini de bozmayacak şekilde yapılır; biri değiştirilirken
  diğeri sessizce etkilenmemeli.
- Ödül fonksiyonu (`r_t = r_yeniAlan − c_bindirme − c_donus − c_enerji − c_carpisma + r_tamamlama`)
  tezde ablation çalışmasına temel oluşturuyor — bu terimlerden biri
  değiştirilirse/kaldırılırsa, hangi terimin neden değiştiği commit
  mesajında ve varsa `docs/` içinde not düşülür.
- `results/` içindeki eğitim çıktılarını **yorumlamak veya isim/formatını
  değiştirmek** yerine, agent yeni bir koşu sonucu üretsin; eski sonuçları
  ezmesin (üzerine yazmadan önce sor).

## Git kuralları — ÖNEMLİ

- **`main` branch'e asla doğrudan commit/push yok.** Her görev için yeni
  bir branch açılır: `feature/<kisa-aciklama>` veya `fix/<kisa-aciklama>`.
- Agent değişikliği yapar, ilgili testleri çalıştırır (en az `runSmokeTests`),
  sonucu özetler, commit mesajını yazar — ama **push ve main'e merge
  kullanıcı onayı olmadan yapılmaz.**
- Commit mesajı formatı: kısa özet satırı + (varsa) hangi testin/koşunun
  sonucunu doğruladığı bir satır. Örnek:
  `fix: coverage ödül fonksiyonundaki enerji terimi işareti düzeltildi (runSmokeTests geçti)`
- `results/` altındaki büyük/binary eğitim çıktıları ve üretilen `.slx`
  dosyaları commit edilmeden önce boyutu kontrol edilir; gerekirse
  `.gitignore`'a eklenmesi kullanıcıya önerilir.
- Zaten var olan `backup-before-merge` branch'ine dokunulmaz.

## Agent nelere DOKUNMAMALI

- `LICENSE` dosyası.
- `docs/TEZ_YOL_HARITASI.md` içindeki plan sırası — sadece kullanıcı
  açıkça bu yol haritasını güncellemeyi isterse değiştirilir.
- `results/` içindeki geçmiş koşu sonuçları (üzerine yazma, silme).

## Görev bittiğinde agent şunu raporlar

1. Hangi dosyalar değişti (kısa liste).
2. `runSmokeTests` (ve varsa ilgili başka doğrulama) sonucu geçti mi.
3. Hangi branch'te olduğu ve commit edilip edilmediği.
4. Kullanıcının onaylaması gereken bir sonraki adım varsa (push, merge,
   uzun `"thesis"` eğitimi gibi) net şekilde belirtilir.
