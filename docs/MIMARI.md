# Sistem Mimarisi ve Çalışma Prensibi

## Tasarım kararı

İlk prototip, fiziksel olarak dört tahrikli tekerli; kontrol açısından sol ve sağ tarafı birlikte sürülen bir skid-steer platformdur. Bu seçim, Lymow sınıfındaki paletli makinelerin çekiş fikrini ve RockMow/LUBA sınıfındaki dört tekerli arazi kabiliyetini, tez için yönetilebilir bir diferansiyel modelde birleştirir.

Mekanikte önerilen düzen:

- Alüminyum sac/ekstrüzyon alt şasi ve UV dayanımlı üst kabuk.
- Dört adet geniş profilli teker; sol ve sağ teker çiftleri aynı hız referansını alır.
- Her tekerde pasif salınım veya kısa stroklu yay-damper; ilk sayısal modelde rijit kabul edilir.
- Gövdenin altında kauçuk izolatörlü yüzer tabla.
- İki küçük kesici disk, toplam yaklaşık 400 mm iş genişliği.
- Önde temas bumperı; çevrede ultrasonik/ToF, ön tarafta kamera; üstte RTK-GNSS anteni.
- Kaldırma ve aşırı eğim halinde kesici motoru donanımsal olarak kesen bağımsız güvenlik hattı.

## Çalışma prensibi

1. Robot bahçe sınırını ve yasak bölgeleri harita olarak alır.
2. Kapsama planlayıcı, serbest hücrelerin biçim sırasını üretir.
3. Yerel takipçi rotayı doğrusal ve açısal hız referanslarına çevirir.
4. Sol/sağ tahrik hızları diferansiyel sürüş denklemleriyle hesaplanır.
5. Biçme tablası sürekli çalışır; yeni biçilen alan ve tekrar geçişler kaydedilir.
6. Enerji, süre, dönüş, bindirme ve çarpışma metrikleri deney sonunda raporlanır.

Sol ve sağ teker hızları:

\[
\omega_R = \frac{v + \frac{b}{2}\dot{\psi}}{r}, \qquad
\omega_L = \frac{v - \frac{b}{2}\dot{\psi}}{r}
\]

Burada `b` iz genişliği, `r` teker yarıçapı, `v` gövde doğrusal hızı ve `dot(psi)` yaw hızıdır.

## Yazılım katmanları

| Katman | Bu sürüm | Sonraki doğrulama |
|---|---|---|
| Bahçe | İkili doluluk ızgarası | Gerçek ortofoto / RTK poligonu |
| Global kapsama | Engelli serpantin + DQN | PPO/SAC, GNN veya hiyerarşik RL |
| Yerel takip | MATLAB hız komutu üretici | Pure Pursuit/MPC ve kayma kestirimi |
| Araç | Simulink 2D kinematik + 1. derece tahrik | Simscape Multibody + lastik-toprak modeli |
| Enerji | Hız/yaw/tablayı kullanan güç yaklaşımı | Ölçülmüş motor haritaları ve batarya eşdeğer devresi |
| Algılama | Bilinen statik engeller | Kamera/LiDAR, dinamik engel ve belirsizlik |

## Simulink modeli

`buildLawnMowerSimulinkModel.m`, `models/LawnMowerPlant.slx` modelini programatik üretir. Böylece ikili `.slx` dosyasını farklı MATLAB sürümlerinde elle düzenlemek yerine model her Windows kurulumunda yeniden kurulabilir.

Modelde:

- `v_cmd_ts` ve `w_cmd_ts` Workspace zaman serileri giriş olur.
- Komutlar sınırlandırılır ve tahrik gecikmesinden geçirilir.
- Diferansiyel kinematikten `x`, `y`, `psi` elde edilir.
- Sol/sağ teker açısal hızları hesaplanır.
- Basit güç modeli tüketilen Wh ve SOC üretir.

## Güvenlik notu

Bu model fiziksel kesici sistem için güvenlik sertifikasyonu değildir. Gerçek prototipte yazılımdan bağımsız acil durdurma, çift kanallı kesici kesme, kaldırma/eğim kilidi, motor kontaktörü ve uygun muhafaza tasarımı gerekir.

