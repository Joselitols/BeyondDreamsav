# Kit Google Flow — Comercial BMW X1 xDrive28i ActiveFlex

Esta pasta tem **13 frames iniciais** (as fotos reais, em alta) + os **prompts prontos**
para você gerar os clipes no Google Flow (labs.google/fx/tools/flow) pelo Chrome,
no modo **"Frames to Video"** (imagem inicial → vídeo), Veo em prioridade baixa.

**Configuração no Flow:** 16:9 · usar a foto da cena como frame inicial · 1 saída por cena.

Depois é só me mandar os clipes (pelo Drive, e-mail ou colocando em
`comercial-bmw-x1/media/` com os nomes `s1.mp4, s2.mp4, s3.mp4, s4.mp4, s5a.mp4,
s5b.mp4, s6a.mp4, s6b.mp4, s6c.mp4, s7a.mp4, s7b.mp4, s8.mp4, s9.mp4`)
que eu remonto o comercial inteiro com ffmpeg — narração, trilha, cartelas e selo.

## Prompts por cena (copie e cole no Flow)

Regra de ouro em todos: **somente movimento de câmera; o carro não muda em nada**.

| Arquivo do frame | Nome no filme | Prompt (cole no Flow) |
|---|---|---|
| cena01_garagem_frontal.jpg | s1 (4s) | Slow smooth camera push-in toward the parked white BMW X1, halo headlights glowing. Camera movement only. The car stays perfectly still; preserve badges, grille, plate and reflections exactly. Premium car commercial. |
| cena02_garagem_traseira.jpg | s2 (3,6s) | Slow lateral camera drift to the right past the rear of the parked white BMW X1, LED taillights glowing. Camera movement only; car perfectly still; preserve badges and license plate exactly. |
| cena03_goldenhour_frontal.jpg | s3 (5s) | Gentle slow arc around the front three-quarter of the parked white BMW X1 at golden hour, warm sun flare. Camera movement only; car perfectly still; preserve wheels, badges, plate exactly. |
| cena04_frente_grade_M.jpg | s4 (4,4s) | Very slow push-in toward the front grille and halo headlights of the parked white BMW X1 in a garage. Camera movement only; nothing on the car changes. |
| cena05a_retrovisor_carbono.jpg | s5a (2,6s) | Macro shot, slow drift over the carbon-look mirror cap of the white BMW X1. Camera movement only; preserve every detail. |
| cena05b_lanterna_activeflex.jpg | s5b (2,6s) | Macro shot, slow drift over the LED taillight and ActiveFlex badge of the white BMW X1. Camera movement only; preserve badge text exactly. |
| cena06a_cockpit.jpg | s6a (5s) | Slow push-in through the open driver door toward the steering wheel and dashboard. Camera movement only; interior stays exactly as photographed; no people, no hands. |
| cena06b_volante.jpg | s6b (2s) | Macro slow drift over the BMW steering wheel with red stitching. Camera movement only; preserve everything exactly. |
| cena06c_painel_111400km.jpg | s6c (2,4s) | Slow push-in toward the instrument cluster display showing the mileage. Camera movement only; the numbers on the display must remain exactly as photographed. |
| cena07a_lateral_rua.jpg | s7a (4s) | Slow lateral dolly along the side profile of the parked white BMW X1 at golden hour. Camera movement only; wheels not turning; no people or shadows of people; preserve plate and badges exactly. |
| cena07b_traseira_palmeiras.jpg | s7b (3,6s) | Slow pull-back revealing the parked white BMW X1 among palm trees at golden hour. Camera movement only; car perfectly still; license plate must remain exactly as photographed. |
| cena08_traseira_sol.jpg | s8 (4,4s) | Slow cinematic drift around the rear three-quarter of the parked white BMW X1 in warm sunlight. Camera movement only; preserve everything exactly. |
| cena09_beauty_garagem.jpg | s9 (5s) | Very slow majestic push-in toward the parked white BMW X1 with headlights on in a bright garage. Camera movement only; car perfectly still. |

Dica: se alguma saída do Flow alterar o carro (placa, rodas, emblemas, geração do
modelo), gere de novo — ou me avise que eu descarto essa cena e uso a foto real.

## Checklist de QA por clipe (antes de aproveitar)
- Placa continua **FLT3H05** do início ao fim
- Emblemas xDrive28i / ActiveFlex / X1 intactos
- Rodas com o mesmo desenho (dupla-raia bicolor)
- Nenhuma pessoa ou sombra de pessoa
- Carro parado (sem rodar roda, sem mudar reflexo bruscamente)
