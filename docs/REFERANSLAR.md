# Tasarım ve Yazılım Referansları

Bu başlangıç modelindeki mekanik değerler bir ürünün kopyası değildir; mevcut bahçe robotlarındaki uygulanmış fikirlerin tez prototipine uygun bir bileşimidir.

- [Roborock RockMow X1](https://garden.roborock.com/us/products/roborock-rockmow-x1): AWD, aktif yönlendirme, arazi kabiliyeti ve kenara yakın biçme yaklaşımı.
- [Roborock RockMow Z1](https://garden.roborock.com/eu/products/roborock-rockmow-z1): dört teker tahriki, engel aşma ve eğim kabiliyeti.
- [Lymow One Plus](https://www.lymow.com/products/lymow-one-plus-robotic-lawn-mower): paletli iki taraflı çekiş, yüzer/rotary biçme yaklaşımı ve yaklaşık 16 inç iş genişliği.
- [Mammotion LUBA 3 AWD](https://us.mammotion.com/products/luba-3-awd-robot-lawn-mower): yaklaşık 15.7 inç biçme genişliği ve çift disk düzeni.

MATLAB/Simulink tarafı:

- [rlFunctionEnv ile özel MATLAB ortamı](https://www.mathworks.com/help/reinforcement-learning/ug/create-matlab-environments-using-custom-functions.html)
- [rlDQNAgent](https://www.mathworks.com/help/reinforcement-learning/ref/rl.agent.rldqnagent.html)
- [rlSimulinkEnv](https://www.mathworks.com/help/reinforcement-learning/ref/rlsimulinkenv.html)
- [Programatik Simulink modelleme — add_block](https://www.mathworks.com/help/simulink/slref/add_block.html)

İlk sürümde RL eğitimi hızlı olması için MATLAB ortamında, araç dinamiği ise Simulink'te tutulur. İkinci fazda ajan bloğu Simulink içine alınarak `rlSimulinkEnv` ile uçtan uca dinamik eğitim karşılaştırması yapılabilir.

