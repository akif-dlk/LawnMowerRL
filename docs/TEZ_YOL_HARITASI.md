# Tez Yol Haritası

## Araştırma sorusu

“Engelli ve düzensiz bahçe alanlarında, enerji ve çim hasarını temsil eden dönüş/bindirme maliyetlerini birlikte dikkate alan pekiştirmeli öğrenme tabanlı kapsama planlama, klasik serpantin kapsama yöntemine göre hangi koşullarda üstünlük sağlar?”

Bu ifade “RL her durumda daha iyidir” varsayımını yapmaz; hangi senaryoda değer ürettiğini ölçülebilir hale getirir.

## Aşama 1 — Sayısal taban çizgisi

- Diferansiyel araç ve enerji modeli.
- Engel farkındalıklı serpantin rota.
- Sabit üç bahçe sınıfı: açık, engelli, dar geçitli.
- Metrikler: kapsama, bindirme, mesafe, dönüş, süre, Wh ve başarısızlık.

Çıkış ölçütü: Aynı başlangıç ve haritada deterministik olarak tekrarlanabilir deney.

## Aşama 2 — RL kapsama planlayıcı

- DQN ile ayrık komşu hücre eylemleri.
- Ödül terimlerinin normalize edilmesi.
- En az 10 bağımsız seed ile eğitim/değerlendirme ayrımı.
- Eğitimde görülmeyen engel düzenlerinde genelleme testi.

Çıkış ölçütü: Ortalama ve güven aralığıyla klasik yöntem karşılaştırması.

## Aşama 3 — Tez yeniliği

Aşağıdakilerden biri ana katkı olarak seçilmelidir:

1. Enerji ve zemin hasarı farkındalıklı ödül şekillendirme.
2. Global kapsama kararı + yerel sürekli kontrol için hiyerarşik RL.
3. Değişken batarya/çim yoğunluğu altında şarj istasyonu dönüşünü içeren kapsama.
4. Sim-to-real için domain randomization: sürtünme, kayma, GNSS ve aktüatör gecikmesi.

İlk öneri 1 + sınırlı domain randomization'dır; ölçmesi ve fiziksel prototipe aktarması daha nettir.

## Aşama 4 — Yüksek gerçeklikli model

- Simscape Multibody şasi, teker ve yüzer tabla.
- Eğimli arazi yüzeyi.
- Sol/sağ kayma ve yuvarlanma direnci.
- Deneyden tanımlanan motor/batarya parametreleri.
- RTK-GNSS, IMU ve enkoder gürültüsü.

## Aşama 5 — Fiziksel doğrulama

- Önce bıçaksız düşük hızlı platform testi.
- Ölçekli yapay çim parkuru.
- Kapalı ve güvenli gerçek çim alanı.
- Simülasyon ve gerçek sistemde aynı görev/metrik seti.

## Deney protokolü

| Değişken | Önerilen seviye |
|---|---|
| Engel yoğunluğu | %0, %5, %10, %20 |
| Harita karmaşıklığı | Dikdörtgen, L biçimi, dar geçit, çok bölgeli |
| Sürtünme/kayma | nominal ± %20 |
| Başlangıç pozu | 5 farklı konum/yön |
| Yöntem | Serpantin, DQN, tezde geliştirilen yöntem |
| Tekrar | En az 10 seed |

Raporlamada yalnızca toplam ödülü kullanmayın. Ödül, algoritmanın optimize ettiği iç ölçüdür; dış başarı ölçütleri ayrı tutulmalıdır.

## Ablation planı

- Dönüş cezası kapalı/açık.
- Enerji cezası kapalı/açık.
- Bindirme cezası kapalı/açık.
- Potansiyel tabanlı ilerleme ödülü kapalı/açık.

Her koşul için kapsama, Wh/m², dönüş/100 m² ve süre/m² raporlanmalıdır.

