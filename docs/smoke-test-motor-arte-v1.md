# Smoke test de integración — asset real en motor, a 26px

**Estado:** pendiente de ejecución — asignado a Mesa de Developers/Director.
**Origen:** `docs/qa-prueba-assets-v1.md` sección 4 (checklist general, escrito por
Dirección de Arte) + sección 5 (decisión de la PM, 09-ago: no ronda 3 de prompt
todavía, resolver primero con este test antes de gastar más créditos).
**No lo ejecuto yo:** sin editor de Godot en este entorno — mismo límite que ya
declaró Arte en la sección 4 de ese documento ("no tengo Godot en este
entorno").

---

## 1. Qué pregunta responde

Una sola: **el acabado "pintado" (gradientes, oclusión ambiental, especular,
desgaste) que salió en la ronda 2 de Arte — ¿sobrevive legible a 26px, o se
pierde y da lo mismo que si hubiera sido flat vector desde el principio?**

Esto **no** es el benchmark de costo — `docs/fase2-vfx-benchmark.md` ya midió
que asignar una textura a un `MultiMeshInstance2D` no mueve el fps
(`entity_render_sync.gd::set_sprite()` swapea una textura por store por
frame, no por instancia). Esto es una pregunta puramente visual: la que la PM
dejó pendiente en `qa-prueba-assets-v1.md` sección 5 antes de decidir si hace
falta una ronda 3 de prompt.

## 2. Insumo exacto

`docs/try-assets/gpt/ChatGPT Image 9 ago 2026, 10_04_12 a.m.png` — cuerpo de
Torreta Recta, ronda 2, la única muestra con el ancla anti-mech ya aplicada.
Alpha real confirmado a nivel de píxel (0 en las 5 muestras de borde,
`qa-prueba-assets-v1.md` sección 5) — no hace falta re-verificar transparencia,
ya está hecho.

Canvas real 1024×1536 (rectangular, no el 1024×1024 cuadrado pedido en el
prompt) — hay que recortar al bounding box del contenido antes de importar
(ver advertencia en el paso 1, es la parte del proceso más fácil de arruinar
la medición sin darse cuenta).

No hay frame de "caminar" — no hace falta, las torres no caminan.
`EntityRenderSync.set_sprite(idle, walk, interval)` pide los dos parámetros
sin default nulo; pasar la misma textura en los dos dá cero animación
visual, que es el comportamiento correcto acá, no un workaround.

## 3. Pasos

1. **Recortar antes de importar.** El canvas tiene márgenes transparentes
   irregulares; si se importa tal cual, el quad de 26px (paso 3) escala el
   *canvas completo* — no la silueta de la torreta. El resultado mediría
   "torreta chica flotando en aire transparente dentro de un quad", no la
   torreta ocupando 26px real, y sesgaría el test hacia "no se lee" de forma
   artificial. Recortar al bounding box del contenido opaco/semi-opaco antes
   de tirar el import (cualquier editor de imagen sirve).
2. **Importar a `game/assets/`** (p. ej. `torreta_recta_v2.png`). No tocar
   configuración de import a mano — los defaults de Godot 4.7 al importar
   como Texture2D ya son los mismos que preservan el alpha real, tal como
   quedaron documentados en `game/assets/characters.png.import`
   (`compress/mode=0`, `process/fix_alpha_border=true`).
3. **Cargar y asignar** en una escena de prueba (no hace falta que sea
   `Level1.tscn` real — más simple aislarlo en una escena chica):
   ```gdscript
   var tex := load("res://assets/torreta_recta_v2.png")
   _tower_render.set_sprite_for_type(0, tex, tex)  # type_id 0 = Torreta Recta
   ```
   `TypedRenderGroup.set_sprite_for_type()` (`game/render/typed_render_group.gd:33`)
   ya existe para esto exacto — ningún cambio de motor hace falta. Es la
   primera vez que se usa desde que se agregó como tarjeta confirmada en
   `diseno-grafico.md` sección 8.
4. **Tamaño real de referencia: 26px** — el quad de torre de la pantalla
   jugable real (`level_controller.gd:101`,
   `TypedRenderGroup.new(..., 26.0, TYPE_COLORS)`), no el 16px del arnés
   sintético (`stress_main.gd:220`, otro contexto, no es el que importa acá).
   Si sobra tiempo, repetir también a 16px es dato extra, pero 26px es el
   número que decide.
5. **Capturar pantalla 1:1** (zoom del viewport al 100%, no ampliado
   después) con tres referencias visibles juntas en la misma captura:
   - El sprite nuevo en el quad de 26px.
   - El placeholder de color plano actual al mismo tamaño, como piso de
     comparación (`TYPE_COLORS[0]` en `level_controller.gd:33` — hoy es
     **azul**, `Color(0.30, 0.55, 0.95)`; ver nota en el criterio 2 antes de
     usarlo como referencia de color correcto, no lo es).
   - La imagen original a 1024px, como referencia de qué detalle existe en
     origen.

## 4. Criterio de salida — 3 preguntas puntuales sobre la captura

No es impresión general ("se ve bien/mal"). Son tres preguntas separadas,
porque cada una manda a una conclusión distinta:

1. **Silueta:** ¿se sigue leyendo "torreta fija sobre patas mecánicas" o
   colapsa en una mancha sin forma reconocible?
2. **Color de firma:** el catálogo (`docs-torretas-diseno.md` #1) asigna a
   esta torreta **blanco/gris acero** — no el azul del placeholder plano
   (ese es solo el color de desarrollo pre-arte, sin relación con el diseño
   final, ver paso 5). ¿A 26px el tono dominante del sprite sigue leyéndose
   como blanco/gris acero, o el sombreado/desgaste lo corre lo suficiente
   para leerse como otro color?
3. **Detalle pintado (gradiente/especular/desgaste):** ¿se distingue del
   todo en la captura de 26px, o dá exactamente el mismo resultado visual
   que hubiera dado flat vector? Esta es la que cierra la pregunta de la PM:
   si "da igual que flat", el detalle extra no cuesta nada gratis y no hace
   falta ronda 3.

**Pasa** (no hace falta ronda 3, greenlight directo al resto del catálogo)
si 1 y 2 son "sí, se lee bien" — con 3 en cualquiera de las dos respuestas,
ya resuelve lo que preguntaba la PM.
**No pasa** (vuelve a Arte) si 1 o 2 fallan — con el motivo puntual (cuál de
las dos, no "no se ve bien" en general) y el ajuste de prompt ya redactado en
`qa-prueba-assets-v1.md` sección 5, punto 2, listo para usar sin re-escribir
nada.

## 5. Qué no prueba esto

- **Costo de fps** — ya cerrado en `fase2-vfx-benchmark.md`, no se repite acá.
- **El proyectil simplificado** — esa corrección de prompt
  (`prompts-arte-torretas-v1.md`) todavía no tiene muestra generada; este
  test es solo sobre el cuerpo de la torreta.
- **Las otras 19 torretas** — una muestra no generaliza el catálogo entero,
  es la validación mínima antes de escalar que la propia Arte pidió en
  `qa-prueba-assets-v1.md` sección 3.

## 6. Entregable

Completar la tabla de veredicto (sección 4, las 3 preguntas) con las
capturas del paso 5 adjuntas — en este mismo documento o en uno de resultado
enlazado desde acá, mismo formato que cualquier benchmark anterior del
proyecto. Vuelve al director con el resultado antes de decidir ronda 3 sí/no.

---

## 7. Resultado (09-ago, ejecutado por Mesa de Developers/Director)

**Veredicto: NO PASA.** Vuelve a Arte — ronda 3, con el ajuste de prompt ya
redactado en `qa-prueba-assets-v1.md` sección 5, punto 2.

### Cómo se corrió

1. Recorte del canvas 1024×1536 al bounding box de contenido opaco/semi-opaco
   (`PowerShell` + `System.Drawing`, el mismo método que Arte ya usó para
   verificar alfa) → 950×1166px, alfa real preservado. Guardado en
   `game/assets/torreta_recta_v2.png`.
2. Import a Godot **sin tocar configuración a mano**, tal como pedía el paso
   2 — confirmé que `mipmaps/generate=false` en el `.import` resultante es
   igual al de `characters.png.import`, mismo default del proyecto, no una
   diferencia introducida acá (nota técnica en la sección 8).
3. `TypedRenderGroup.set_sprite_for_type(0, tex, tex)` — primer uso real
   desde que se agregó como tarjeta de motor. Sin frame de caminar, tal como
   anticipaba el paso 2.
4. Corrida real en `Level1.tscn` (no el arnés sintético), **Vulkan real
   confirmado** (`Vulkan 1.3.260 - Forward+ - Using Device #0: AMD - Radeon
   RX Vega`), quad de **26px real** (`level_controller.gd:101`) — una torre
   tipo 0 (con el sprite) junto a una tipo 1 (color plano, piso de
   comparación de tamaño).
5. Captura 1:1 del viewport (`level1_screenshot_t6.png`), recorte nativo sin
   reescalar alrededor de la torre con sprite
   (`sprite_test_crop_1to1.png`, 36×36px reales) — esa es la medición.
   Además, una versión ampliada ×10 **sin interpolar** (nearest-neighbor,
   `sprite_test_crop_nearest10x.png`) solo para poder mirarla en esta
   respuesta — aclarado acá porque el paso 5 pide explícitamente no ampliar
   la captura que se usa como medición; la ampliación es una ayuda de
   inspección, no el dato.

### Las 3 preguntas

1. **Silueta — no se lee.** A 26px reales colapsa en una mancha oscura de
   líneas finas que se leen como patas/puntas irradiando en varias
   direcciones — más cercano a "explosión" o "araña" que a "torreta fija
   sobre patas mecánicas". El contorno tripode + cañón que sí se lee
   perfecto a 1024px desaparece por completo a esta escala.
2. **Color de firma — no se lee.** El catálogo pide blanco/gris acero como
   color de firma de esta torreta. A 26px el tono dominante que sobrevive es
   **oscuro/negro** (el line-art y las sombras, no el cuerpo claro) — el
   gris acero queda enterrado bajo el contraste de las líneas.
3. **Detalle pintado — pregunta superada por los dos puntos de arriba.** No
   llega a ser "¿se distingue de flat o da igual?": el problema no es que el
   detalle pintado sea redundante, es que a esta escala **activamente
   destruye la lectura de silueta y color** — más grave que lo que la PM
   estaba preguntando.

### Veredicto formal

Con 1 y 2 fallando, corresponde **no pasa** según el criterio ya fijado en
la sección 4 de este documento (no lo re-defino acá). Motivo puntual para
Arte: no es "el detalle no se nota" — es que el detalle pintado, a 26px,
lee peor que un flat vector simple leería. La ronda 3 con el prompt de
anclaje de estilo más agresivo (`qa-prueba-assets-v1.md` sección 5, punto
2: "Flat design... no shading gradients, no ambient occlusion, no specular
highlights...") es exactamente la corrección que este resultado pide.

## 8. Corrección: bug de orientación invalidaba la sección 7 (09-ago)

**La sección 7 se midió con el sprite rotado 180° por un bug de motor, no
por el asset.** El usuario lo notó revisando la imagen a ojo (de cabeza,
apuntando al revés del original) y pidió revisarlo. Confirmado con un
diagnóstico dedicado: un `Sprite2D` con la misma textura (referencia de
verdad, 2D nativo) contra el mismo asset por el camino real del juego
(`EntityRenderSync` → `QuadMesh` + `MultiMeshInstance2D` en modo
`TRANSFORM_2D`) — el segundo salía sistemáticamente rotado 180° respecto
del primero, a cualquier tamaño. Causa: Godot 2D es Y-hacia-abajo, `QuadMesh`
asume Y-hacia-arriba por default — sin corregirlo, cualquier sprite
asimétrico sale invertido en Y (con los cuadrados/círculos de color plano
de siempre esto era invisible: una figura simétrica invertida en Y se ve
idéntica, por eso nunca se detectó hasta el primer sprite real).

**Fix** (`entity_render_sync.gd`): corrección de Y aplicada una sola vez en
`sync()`, para todos los stores (enemigos/proyectiles/torres). Verificado
con barrido de las 4 combinaciones de signo posibles contra el `Sprite2D`
de referencia antes de confirmar cuál era la correcta — no alcanzaba con
"ya se ve bien" en una sola comprobación después del primer intento fallido
(el primer intento de corrección, por rotación en vez de flip de un solo
eje, coincidía visualmente con dos muestras pero no explicaba el mecanismo
real y no sobrevivió la prueba de un tercer punto de comparación).

**De regalo, ya que había que tocar esto:** `set_flip_h()`
(`EntityRenderSync`) y `set_flip_h_for_type()` (`TypedRenderGroup`) — mirror
horizontal real, verificado contra la misma referencia. Es lo que pide el
segundo punto del usuario: **convención a futuro, arte preparado apuntando
a la izquierda, espejado a la derecha cuando haga falta** (por ahora
estático por tipo — el click-and-drag de apuntado, cuando exista, va a
necesitar flip por instancia, no por tipo; no lo construyo todavía porque
no hay input que lo consuma). Importante: **este asset en particular
(`torreta_recta_v2.png`) apunta a la derecha en origen, no a la
izquierda** — la convención "apunta a la izquierda por default" es para
lo que se genere de acá en más, no reinterpreta el asset ya generado.

### Sección 7, re-corrida con la orientación ya corregida

Mismo método, misma captura 1:1 a 26px reales, ahora con la rotación
arreglada:

1. **Silueta — mejora real, sigue sin ser un "sí" limpio.** Con la
   orientación correcta se distingue una masa de cuerpo, un cañón
   horizontal, y patas — más que la lectura de "araña/explosión" de la
   sección 7 original, que en parte era la rotación empeorando la lectura,
   no solo la densidad de detalle. Pero sigue siendo una silueta ocupada,
   no una lectura inmediata de "torreta fija sobre trípode" a primera
   vista.
2. **Color de firma — sin cambio de veredicto.** El negro del line-art
   sigue dominando sobre el gris acero del cuerpo a esta escala. La
   rotación no era la causa de esto — es densidad de detalle/contraste,
   independiente de la orientación.
3. **Detalle pintado — sin cambio.** Sigue leyéndose ruidoso, no flat.

**Veredicto revisado: sigue sin pasar, pero ya no por "colapsa en una
mancha irreconocible"** — colapsaba en parte por estar al revés. Corregido
eso, el problema real y remanente es exactamente el que ya había
identificado la sección 5 de `qa-prueba-assets-v1.md`: acabado pintado
(gradientes, especular, desgaste) que no sobrevive limpio a 26px. **No
cambia la recomendación de ronda 3** — la confirma con mejor evidencia,
no la contradice. Capturas: `sprite_test_crop_nearest10x_fixed.png`
(torreta sola, ×10 sin interpolar) y `sprite_test_both_nearest10x_fixed.png`
(torreta + referencia de color plano, mismo tamaño).

## 9. Nota técnica aparte, no cambia el veredicto

`torreta_recta_v2.png.import` quedó con `mipmaps/generate=false` — igual
que `characters.png.import`, así que es el default ya establecido del
proyecto, no algo que este test cambió. Vale dejarlo anotado igual: sin
mipmaps, downscalear ~36× (950px → 26px) sin un nivel pre-filtrado agrava
el aliasing de líneas finas — es plausible que **parte** de lo que se ve en
la sección 7 sea artefacto de filtrado, no solo densidad de detalle del
arte. No lo tomo como excusa ni cambio el veredicto: el test mide cómo se
ve el juego **hoy, con la configuración real**, que es la pregunta que
hizo la PM. Si la ronda 3 no alcanza, generar mipmaps es la siguiente
palanca de motor a probar antes de pedir una ronda 4 — más barato que otra
tanda de créditos de generación.

## 10. Próximos pasos (coordinador, 09-ago)

**Causa adicional del fallo #2, encontrada al preparar la ronda 3.** El
preámbulo compartido (`prompts-arte-torretas-v1.md` sección A) pedía "bold,
clean dark outlines" — eso, no solo la falta de anclaje flat, es lo que
enterró el gris acero bajo el line-art a 26px. Corregido directo en el
preámbulo (afecta las 20 torretas, no solo esta), fusionado con el ajuste
de `qa-prueba-assets-v1.md` sección 5 punto 2 en un solo bloque — no hace
falta pegar dos textos separados en la ronda 3.

**Tarjeta — Arte.** Ronda 3 de Torreta Recta (cuerpo) con el preámbulo ya
corregido, un solo paste. Si pasa: mismo preámbulo para el resto del
catálogo de 20. Si vuelve a fallar el color de firma puntualmente (no la
silueta ni el detalle pintado), el problema no es de prompt — es de
herramienta o de que el color de firma en sí (blanco/gris claro) tiene poco
contraste inherente contra outline+sombra a esta escala, y ahí sí
ameritaría replantear el criterio de color por torreta, no otra vuelta de
prompt.

**Tarjeta — Motor/Mesa de Developers.** En paralelo, no bloquea ni depende
de la ronda 3: probar `mipmaps/generate=true` en
`game/assets/torreta_recta_v2.png.import` sobre el asset ya recortado y
repetir la misma captura 1:1 a 26px (mismos pasos de la sección 3, mismo
asset, sin gastar créditos de Arte). Aísla cuánto de los fallos #1/#3
originales era aliasing de downscale (~36×, sección 9) contra contenido
real del arte — dato útil independiente del resultado de la ronda 3, y más
barato correrlo ahora que como palanca de emergencia después de una ronda 4.

**No hay decisión de Director/PM pendiente acá** — ambas tarjetas son
independientes entre sí y de bajo costo; correrlas en paralelo es el default
razonable, no algo que necesite aprobación aparte.

## 11. Resultado — tarjeta de Motor/Mesa de Developers (mipmaps, 09-ago)

**Hallazgo principal: `mipmaps/generate=true` solo, sin más, no cambia
nada.** El resultado inicial (mismo método de la sección 3, mismo asset,
solo el `.import` tocado) fue visualmente indistinguible de la sección 8 —
confirmado con una métrica de ruido pixel-a-pixel (variación total de
luminancia entre vecinos, sobre el recorte 36×36 real): **11.97 sin mipmaps
vs. 12.06 con mipmaps, -0.7%**, dentro de ruido de medición. Antes de
concluir "los mipmaps no sirven acá" — que hubiera sido la lectura fácil —
paré a preguntar *por qué* no había ningún cambio, en vez de aceptar el
número al primer intento (mismo criterio que ya costó caro con el bug de
fire_rate=0.0 de la sección 6 de `fase2-benchmark-conjunto.md`: dos cosas
que se cancelan o, acá, una que directamente no está actuando, dan un
resultado que "parece" concluyente sin serlo).

**Causa: el proyecto nunca usa los mipmaps que genera.** `game/project.godot`
no tiene `rendering/textures/canvas_textures/default_texture_filter` — corre
con el default de Godot 4, **Linear sin mipmaps**. Generar la cadena de
mipmaps en el `.import` no alcanza si ningún `texture_filter` en el árbol de
render los muestrea; es exactamente el mismo tipo de trampa que la nota
técnica de la sección 9 ya avisaba de pasada, pero resultó ser la causa
completa del "sin cambio", no un matiz menor.

**Verificación con la variable aislada correctamente:** agregué
`EntityRenderSync.set_texture_filter()` /
`TypedRenderGroup.set_texture_filter_for_type()` (diagnóstico, no cambia el
default del juego — hace falta llamarlo a mano) y forcé
`TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` en el tipo 0 para una tercera corrida
(`sprite-test-mipmap-filter=...`, mismo asset con mipmaps ya generados).
Resultado, mismo recorte 36×36:

| Variante | Ruido pixel-a-pixel (TV) | Luminancia media |
|---|---|---|
| Sin mipmaps (sección 8) | 11.97 | 89.3 |
| Con mipmaps, filtro default (Linear) | 12.06 (+0.7%) | 89.4 |
| Con mipmaps + filtro `LINEAR_WITH_MIPMAPS` | **3.33 (-72.2%)** | 89.1 |

Comparación visual, mismo recorte, izquierda a derecha (sin mipmaps / con
mipmaps sin filtro / con mipmaps + filtro):
`sprite_test_compare_3way.png`.

**Con el filtro realmente activo, sí hay una mejora real y visible** —no
solo en el número. La silueta deja de leerse como ruido de alta frecuencia
y colapsa en formas más coherentes (masa de cuerpo + patas reconocibles sin
esfuerzo); el contraste duro entre line-art negro y cuerpo gris se suaviza,
así que el gris acero deja de quedar "enterrado" por líneas negras aisladas.
Dato honesto en contra de leerlo como solución completa: la **luminancia
media no cambia** (89.3 → 89.1) — el mipmap no aclara el tono general, solo
redistribuye el contraste local. Y hay un costo: el cañón y el contorno
pierden nitidez (blur real, no solo menos ruido) — un poco de la lectura de
"silueta mecánica definida" se cambia por "silueta más limpia pero más
blanda". No corrí un criterio de aceptación formal (las 3 preguntas de la
sección 4) sobre esta variante — es la misma torreta ronda 2 con el mismo
problema de fondo (acabado pintado a 26px), no una torreta nueva; falta el
juicio de Arte/Director sobre si "más limpio pero más blando" es una mejora
neta o un intercambio que no vale la pena.

**No cambia el veredicto de la sección 8** (sigue "no pasa", ronda 3 en
curso) — pero sí cambia el dato que alimentaba la sección 9: la palanca de
mipmaps **no es gratis como "solo tocar el `.import`"** (eso no hace nada),
pero **si se activa correctamente (`texture_filter` + `mipmaps/generate`),
sí mueve la aguja de forma medible**, no es un descarte. Si la ronda 3 no
alcanza, esto queda como palanca de motor con datos reales detrás, no una
hipótesis sin probar — y es independiente del cambio de preámbulo de la
ronda 3 (sección 10), se pueden evaluar juntas sobre la misma muestra
cuando esté.

**Costo:** cero créditos de Arte, ~15 minutos, sin tocar el default de
`texture_filter` del proyecto (queda gateado detrás de
`sprite-test-mipmap-filter=` para no afectar nada del juego real todavía).
Vuelve al director/PM para decidir si vale la pena setear
`default_texture_filter` a nivel de proyecto (afecta a las 20 torretas del
catálogo, no solo esta) o dejarlo por torreta cuando cada una tenga sprite
— esa es una decisión de alcance, no de motor.

## 12. Resultado — ¿ayuda una fuente más chica? (09-ago, pregunta del usuario)

**Pregunta:** el usuario generó dos versiones más chicas de la misma
Torreta Recta (achicadas a partir de la muestra ronda 2 ya aprobada como
referencia de espejado, no una generación nueva de Arte —
`docs/try-assets/gpt/result_...fliped - copia.png`, 355×422, y
`result_result_...fliped - copia.png`, 107×127) y preguntó si acercar el
tamaño de origen al tamaño real de juego (26px) resuelve el problema, y de
ser así, qué tamaño exacto pedirle a Arte para no tener que reescalar nunca
en motor.

### Cómo se corrió

Mismo método de las secciones 8/11: recorte al bounding box de alfa
(padding=2) → `torreta_recta_v3_med.png` (334×410) y
`torreta_recta_v3_small.png` (105×127) → import default → `sprite-test=`
real en `Level1.tscn`, Vulkan real, quad de 26px, mismo recorte 36×36
fijo. Métrica de ruido igual que en la sección 11 (variación de luminancia
entre píxeles vecinos), esta vez **excluyendo fondo y proyectiles en
tránsito** de la medición (un proyectil cruzó cerca de la torre en algunos
frames — ruido de simulación, no del asset; ver
`sprite_test_compare_4way_sizes.png` para las capturas crudas con el
proyectil visible al costado).

| Variante | Ruido (TV, menor = mejor) | Luminancia media |
|---|---|---|
| 950px fuente, sin mipmaps (baseline sección 8) | 69.18 | 87.7 |
| 334px fuente, sin mipmaps | 62.87 | 87.1 |
| 105px fuente, sin mipmaps | **42.63** | 88.8 |
| 950px fuente + mipmaps + filtro correcto (sección 11) | 15.34 | 87.7 |
| 105px fuente + mipmaps + filtro correcto | **13.45** | 82.2 |

Comparación visual de las primeras 4 filas, mismo recorte, en orden:
`sprite_test_compare_4way_sizes.png`.

### Respuesta a la pregunta

**Sí ayuda, pero no alcanza sola.** El ruido baja de forma consistente al
achicar la fuente (950→334→105px: 69→63→43), confirmando la intuición del
usuario — menos relación de downscale, menos aliasing. Pero incluso la
fuente más chica probada (105px, todavía ~4× más grande que el render
final) se queda lejos de lo que logra **arreglar el filtro de mipmaps solo**
sobre la fuente grande sin tocar (43 vs 15) — la palanca de motor de la
sección 11 sigue siendo la que más mueve la aguja. Combinar las dos
(fuente chica + mipmaps + filtro) da el mejor número de todos (13.45), pero
la ganancia extra sobre "fuente grande + mipmaps + filtro" es marginal
(~12%) — la mayor parte de la mejora ya la daba el filtro, no el tamaño de
origen.

**Caveat importante, no menor:** las dos muestras chicas son **recortes
achicados de la misma pintura grande** (mismo detalle pintado, solo
promediado al reducir), no una generación nueva de Arte pedida
directamente en 355px o 107px. No sé si pedirle a la IA generadora que
dibuje nativamente en un lienzo chico daría un resultado distinto (mejor o
peor) al de simplemente achicar la pintura grande — esa pregunta específica
no está probada acá y no la voy a inferir. Si se quiere probar de verdad,
hace falta una generación nueva a propósito, con costo de créditos de Arte
— no lo recomiendo como próximo paso dado lo poco que sumó el tamaño de
fuente por sí solo frente al filtro, que es gratis.

### Hallazgo adicional (no buscado): el quad de torre fuerza aspecto cuadrado

Verificando esto armé una comparación directa `Sprite2D` (referencia,
preserva aspecto) vs. el `MultiMeshInstance2D` real del juego, mismo
tamaño nominal (`orientation-test=`, capturas
`aspect_ref_sprite2d.png` / `aspect_entityrendersync.png`): **el quad de
torre es cuadrado fijo (`quad.size = Vector2(quad_size, quad_size)` en
`entity_render_sync.gd`), sin importar el aspecto real del source.** La
Torreta Recta (950×1166, más angosta que alta, aspecto 0.815) se ve
perceptiblemente más "achatada/ancha" en el `MultiMeshInstance2D` que en
la referencia `Sprite2D` de al lado — comparación visual en las dos
capturas de arriba. No es sutil una vez que se ponen los dos lado a lado a
gran tamaño; a 26px reales queda enmascarado por el resto del ruido, pero
está.

**Esto es relevante directamente para la pregunta de qué tamaño pedirle a
Arte.**

### Recomendación de tamaño

**No pediría a Arte que genere en un tamaño exacto de píxeles fijo.** Tres
razones:

1. El motor fuerza cuadrado hoy — pedir "26×26 exacto" no resuelve nada
   mientras el quad siga siendo cuadrado y el arte siga siendo
   naturalmente vertical (robot sobre trípode); seguiría distorsionándose.
   Arreglar esto es una tarjeta de motor chica y separada (guardar
   ancho/alto por tipo en vez de un solo `quad_size` cuadrado) — recién
   ahí tendría sentido pedirle a Arte un lienzo con el aspecto real de
   cada pieza.
2. Un tamaño de píxeles exacto es frágil: cualquier ronda futura de ajuste
   de prompt (como la ronda 3 en curso, sección 10) no va a salir en el
   pixel exacto que se pidió, y cada revisión de Arte tendría que volver a
   encajar en esa medida — costo de coordinación recurrente por una
   ganancia marginal (~12% sobre lo que ya da gratis el filtro).
3. La palanca que más rinde (mipmaps + filtro correcto, sección 11) es
   **gratis, de motor, y no le pide nada nuevo a Arte** — funciona sobre
   cualquier tamaño de fuente que Arte entregue, presente o futuro.

**Lo que sí recomendaría, en orden:** (a) resolver primero la sección 11
(activar el filtro de mipmaps, decisión de Director/PM ya pendiente ahí);
(b) si eso más la ronda 3 en curso no alcanza, ahí sí vale la pena la
tarjeta de motor del quad no-cuadrado, para que Arte pueda trabajar en el
aspecto natural de cada pieza sin que el render lo aplaste — pero como
mejora de fidelidad, no como sustituto de (a); (c) no gastaría créditos de
Arte en una generación nativa a tamaño chico hasta agotar (a) y (b), dado
lo que ya se midió acá.

Si el director prefiere confirmarlo a ojo antes de decidir, las capturas
de esta sección (`sprite_test_compare_4way_sizes.png`,
`aspect_ref_sprite2d.png` vs `aspect_entityrendersync.png`) alcanzan sin
correr nada de nuevo.
