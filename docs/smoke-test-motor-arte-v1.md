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
