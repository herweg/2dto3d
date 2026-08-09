# QA de la primera prueba de assets — Gemini vs GPT, y definición del smoke test

**Estado:** hecho — 09-ago-2026.
**Rol:** Dirección de Arte.
**Insumo:** `docs/try-assets/` (11 imágenes: 8 generadas en Gemini, 2 en GPT,
1 mal ubicada — ver sección 1), corriendo a mano una muestra de los prompts
de `docs/prompts-arte-torretas-v1.md`.

---

## 0. Corrección propia, antes que nada

Mi primera lectura de estas imágenes fue visual y estuvo mal: dije que
Gemini respetaba el fondo transparente y GPT no, basándome en cómo se veía
cada imagen en el visor. El usuario lo cuestionó con razón. Verifiqué el
canal alfa real (PowerShell + `System.Drawing.Bitmap`, muestreando 5 puntos
de fondo por imagen — 4 esquinas + borde superior centro) en vez de
confiar en el render del visor, y el resultado es el opuesto de lo que
había dicho. Sección 1 tiene los números; lo importante para no repetir el
error: **un checkerboard *dibujado como píxeles* y un checkerboard *real de
UI mostrando transparencia* se ven casi idénticos a simple vista.** La
próxima vez que la pregunta sea "¿esto es transparente de verdad?", se
verifica con una herramienta, no a ojo.

---

## 1. Qué mide realmente el canal alfa

| Origen | Alpha medido en el fondo | Qué es en realidad |
|---|---|---|
| Gemini — 8/8 archivos (`docs/try-assets/gemini/`) | **255 (opaco)** en las 5 muestras, con RGB gris que varía imagen a imagen (77–228) | El modelo **pintó una grilla de ajedrez gris como píxeles reales**, imitando el ícono de "fondo transparente" de un editor de imágenes — no hay transparencia, es una imagen 100% opaca con un patrón de cuadros dibujado encima. |
| GPT — 2/2 archivos reales (`docs/try-assets/gpt/ChatGPT Image...png`) | **0 (transparente real)** en las 5 muestras | El gris uniforme que se ve en un visor es ese visor rellenando el área vacía para mostrarla — el archivo no tiene esos píxeles. |
| Archivo mal ubicado en `gpt/` (`Gemini_Generated_Image_w8pcl9...png`) | **0 (transparente)** | Se comporta como salida de GPT, no como las otras 8 de Gemini — asumo que quedó mal nombrado/mal copiado a esa carpeta durante las pruebas, no lo cuento como muestra de Gemini ni de GPT (tampoco corresponde a ninguno de los 7 prompts del catálogo — es un edificio/bunker, no una torreta). |

Metodología: `Add-Type -AssemblyName System.Drawing`, `Bitmap.GetPixel()`
en 4 esquinas + borde superior centro de cada imagen, valor de canal `A`
leído directo — no inferido del render.

---

## 2. Veredicto

**GPT gana en las dos dimensiones que importaban, no es un empate
gusto-vs-función.** Transparencia real (confirmada a nivel de píxel) *y*
la preferencia estética que el usuario ya tenía a simple vista van en la
misma dirección.

**Gemini tiene una falla real, y probablemente no se arregla con mejor
prompt.** Sin salida de alfa nativa en su generación de imágenes, cualquier
pedido de "fondo transparente" se resuelve dibujando una aproximación
visual (la grilla) en vez de transparencia real — es una limitación de la
herramienta, no del prompt. **Recomendación: estandarizar en GPT para este
uso (assets con alpha que van directo al motor), descartar Gemini** salvo
que en algún momento se quiera reintentar con alguna variante de
prompt/configuración específica de esa herramienta.

**Lo que sí sigue siendo un problema real, y es de GPT — dos cosas:**
1. **Deriva de silueta**: el cuerpo de torreta salió como mini-mech
   bípedo (piernas, postura de personaje) en vez de "torreta fija sobre
   trípode" (`ChatGPT Image 9 ago 2026, 08_59_08 a.m.png`). La palabra
   "turret" sola no ancla lo suficiente la silueta correcta para este
   modelo — necesita un negativo explícito.
2. **Sobre-detalle en proyectiles**: en ambas herramientas, los
   proyectiles salieron con remaches, brillos especulares y sombreado que
   el "tiny, simple, minimalist" pedido no debería producir — ruido que no
   se lee a los 14-26px de render real (`level_controller.gd`,
   `stress_main.gd`) pero que sí complica mantener consistencia entre 60+
   generaciones si no se corrige ahora.

Ya corregí las dos cosas en `docs/prompts-arte-torretas-v1.md` sección A
(preámbulo compartido + nota de simplificación para proyectiles) y
reescribí el par base/medio de Torreta Recta como ejemplo concreto
aplicado — es la plantilla a repetir cuando se generen los prompts de
proyectil del resto del catálogo (no reescribí las 20 torretas ahora).

---

## 3. Respuesta directa a las preguntas del usuario

**¿Qué opino, GPT o Gemini?** GPT, y no es solo gusto — Gemini falla el
requisito no negociable de transparencia real, verificado a nivel de
píxel, no solo de apariencia.

**¿Sirve este flujo?** Sí. Las dos herramientas leyeron bien la
arquitectura del prompt (color de firma correcto, lenguaje "industrial
fronteriza" reconocible, torreta fija identificable pese a la deriva de
silueta en GPT). No hace falta replantear el enfoque de prompting, solo
ajustarlo — ya hecho en la sección 2.

**¿Voy con las 20 imágenes ya?** Todavía no. Antes, una ronda 2 chica (2-3
prompts, no las 20) **solo en GPT**, con los dos prompts ya corregidos de
Torreta Recta como punto de partida, para confirmar que el ancla de
silueta y la simplificación de proyectil funcionan antes de escalar. Si
esa ronda 2 sale bien, ahí sí tiene sentido ir con el resto del catálogo.

---

## 4. El smoke test — quién hace qué

Es de los dos lados, no de uno solo, y son dos preguntas distintas:

**QA de arte (Dirección de Arte — ya hecho en este documento).** ¿El
resultado cumple estilo, paleta, color de firma, y transparencia real? Se
resuelve mirando las imágenes y verificando el canal alfa — no hace falta
Godot para esto, y es lo que hicieron las secciones 1-2.

**Smoke test de integración (equipo de motor/director — no es mío).**
Una pregunta distinta que ninguna imagen aislada a 1024×1024 responde: ¿el
asset se comporta bien *en el motor real*? Checklist concreto para esa
corrida, mismo reparto de roles que ya se usó para el benchmark de VFX
(`docs/diseno-grafico.md` sección 6 — lo corre quien tiene el arnés de
Godot a mano, no yo):

1. Importar 1-2 assets ya aprobados de GPT (cuerpo de Torreta Recta +
   proyectil base corregido) a Godot y confirmar que el import respeta el
   alpha (`characters.png.import` como referencia de config ya usada).
2. Confirmar legibilidad real a los tamaños de quad ya en uso (14-26px
   según `level_controller.gd`/`stress_main.gd`) — la pregunta que
   ninguna muestra en aislado a 1024×1024 puede responder por sí sola.
3. Confirmar que asignar la textura a un `MultiMeshInstance2D`
   (`entity_render_sync.gd`) no rompe nada del pipeline existente ni
   introduce costo nuevo fuera de lo ya medido en
   `docs/fase2-vfx-benchmark.md`.
4. Si pasa: greenlight para que Arte genere el resto del catálogo sobre
   GPT con los prompts corregidos. Si no pasa (por ejemplo, el detalle
   sigue sin leerse bien a 14px pese a la simplificación): vuelve a Arte
   con el motivo puntual, no a rehacer todo el flujo desde cero.

No lo ejecuto yo en este documento — no tengo Godot en este entorno; queda
como pedido explícito al rol de motor/director, igual que el benchmark de
VFX.

---

## 5. Ronda 2 — resultado con una sola muestra (09-ago)

El usuario corrió el prompt corregido de **cuerpo de Torreta Recta**
(sección B de `prompts-arte-torretas-v1.md`, con el ancla anti-mech ya
sumada al preámbulo) y se quedó sin créditos después de una sola imagen —
`docs/try-assets/gpt/ChatGPT Image 9 ago 2026, 10_04_12 a.m.png`. Una
muestra no es una ronda completa; esto es una lectura parcial, no un
cierre de la pregunta de estilo.

**Verificación de alfa** (misma metodología que la sección 1, no repito el
error de leerlo a ojo): `System.Drawing.Bitmap`, canvas real 1024×1536
(rectangular, no el 1024×1024 cuadrado que pedí — no lo tomo como
problema, el asset sigue siendo recortable). Las 5 muestras de
esquina/borde dieron **alpha=0** — transparencia real, tercera muestra de
GPT seguida que la cumple (2/2 en ronda 1, 1/1 acá). El halo blanco
brillante que se ve alrededor de la torreta en cualquier visor no es fondo
pintado: es un degradé real de alfa parcial (glow) que se desvanece a
alpha=0 antes de llegar al borde — comportamiento correcto de una
transparencia bien formada, no una falla.

**Contra los dos problemas puntuales de la ronda 1:**

- **Ancla anti-mech: funcionó.** Torreta fija sobre patas mecánicas
  splayed hacia afuera, sin postura bípeda ni lectura de personaje —
  corrige exactamente la deriva que se vio en `...08_59_08...png`.
- **Minimalismo de proyectil: sin dato.** Esta muestra es el cuerpo, no un
  proyectil — la corrección de esa sección (`prompts-arte-torretas-v1.md`,
  ejemplo de Torreta Recta base/medio) sigue sin probarse.

**Hallazgo nuevo, no buscado — el más importante de este resultado:** el
acabado sigue leyéndose **pintado/renderizado** (gradientes de sombreado,
oclusión ambiental, brillos especulares, textura de desgaste con ruido de
grises) — no el "flat vector, 2-3 tone cel-shading" que pedí ni la técnica
que el director cerró en `docs/diseno-grafico.md` sección 9, precisamente
por legibilidad a los 14-26px de render real. Es una imagen vistosa y con
silueta limpia, pero **no es la técnica decidida** — el ancla anti-mech
resolvió la silueta sin resolver esto: son dos ejes independientes del
prompt, y con este resultado no sé todavía si el segundo (técnica) también
necesitaba su propio refuerzo explícito o si es un límite real de la
herramienta, igual que pasó con el alfa de Gemini. No lo sé con una sola
muestra — es la pregunta que abre la ronda 3.

### Veredicto de esta ronda

**Satisface, parcialmente — no de forma completa.** Lo que se propuso
arreglar (silueta) se arregló. Lo que no se tocó (proyectil) sigue sin
dato. Y apareció un problema no buscado (técnica pintada vs. flat vector)
que es más importante que los dos anteriores, porque toca directamente la
razón por la que el director eligió flat vector en primer lugar.

**¿GPT sigue siendo la mejor opción?** Sí, sigue siendo mi recomendación —
no tengo evidencia de una alternativa mejor, y de hecho ahora tiene tres
muestras seguidas con alfa real (0/8 en Gemini, 3/3 en GPT). No la cambio
por el hallazgo de técnica: es un problema de *prompt*, no de herramienta
todavía — no hay nada que sugiera que GPT es incapaz de un estilo flat
(muchos generadores producen flat design si se lo ancla con referencias
concretas de estilo, tipo "material design icon" o "flat sticker
illustration, no shading gradients, no drop shadow, no bevel"); lo que
faltó fue anclar ESE eje con la misma fuerza con la que anclé la silueta.
No lo pruebo yo mismo — sin créditos no hay ronda 3 posible ahora mismo.

**Lo que le pido al director, para que lo vea antes de que Arte siga
gastando créditos:**
1. **Decisión de secuencia:** ¿esperamos una ronda 3 (prompt con anclaje
   de estilo más agresivo) antes de dar luz verde a producir el resto del
   catálogo, o aceptamos este acabado más pintado y lo remitimos
   directamente al smoke test de motor (sección 4) para que el veredicto
   de legibilidad a 14-26px lo resuelva con datos en vez de con mi
   apreciación a 1024px?
2. **Si se acepta ronda 3:** el ajuste de prompt que propondría (agregar
   al preámbulo de `prompts-arte-torretas-v1.md` sección A): `Flat design,
   flat illustration, sticker/icon style — solid flat color fills only, no
   shading gradients, no ambient occlusion, no specular highlights, no
   drop shadow, no bevel, no weathering/grunge texture noise. Think flat
   mobile-game icon, not a rendered 3D asset.` — más agresivo que lo que ya
   está, porque "flat vector... NOT painterly" solo no alcanzó.
3. Ninguna de las dos opciones bloquea nada más del proyecto — el catálogo
   de torretas, la paleta, y el resto de `docs/diseno-grafico.md` siguen
   cerrados sin cambios.

> **PM — decisión de secuencia, 09-ago.** Vamos con la opción 2: no ronda 3
> todavía. El nivel de detalle que muestra esta muestra (gradientes,
> especular, desgaste) se ve "de más" a 1024px, pero esa apreciación es
> exactamente la que la sección 4 ya identificó como insuficiente por sí
> sola — la pregunta real es si ese detalle sobrevive o se pierde a los
> 14-26px de render real. **Si el smoke test de motor (sección 4) muestra
> que es un problema real de legibilidad, lo atacamos con la ronda 3 (el
> ajuste de prompt ya redactado en el punto 2 de arriba, listo para usar).
> Si el smoke test muestra que se absorbe bien a esa escala — que los
> quads son tan chicos que el detalle extra no se distingue del flat
> vector que buscábamos — no gastamos otra ronda de créditos en algo que
> el motor ya resuelve gratis.** Pasa a Mesa de Developers/Director: correr
> el smoke test de la sección 4 con esta misma imagen (cuerpo de Torreta
> Recta) antes de pedir más generaciones.

---

## 6. Ronda 3 — prompt único listo, esperando corrida (09-ago, tarjeta de commit `737b11a`)

El smoke test de motor sí se corrió (`docs/smoke-test-motor-arte-v1.md`,
secciones 7-8) — no pasó, y en el camino encontró y corrigió un bug real de
motor ajeno al arte (sprites invertidos 180° en `MultiMeshInstance2D` por
un desajuste de convención de eje Y entre `QuadMesh` y Godot 2D, ya
arreglado en `entity_render_sync.gd`). Con la orientación corregida, la
silueta mejoró pero el color de firma siguió sin leerse a 26px — y el
coordinador encontró la causa raíz exacta que a mí se me había pasado en
la ronda 2: el preámbulo pedía **"bold, clean dark outlines"**, y eso es
lo que enterraba el gris acero bajo el line-art, independiente del
detalle pintado que yo había señalado como sospechoso principal.

**Ya actualicé `prompts-arte-torretas-v1.md`:** el preámbulo de la sección
A trae ese fix fusionado con el ajuste de flat-anchoring que ya había
dejado redactado en la sección 5 de este documento (outline fino y
secundario al relleno, 2-3 tonos planos, sin gradiente/AO/especular/
bisel/desgaste). Y agregué, en la entrada de Torreta Recta (sección B),
un bloque único con preámbulo + cuerpo ya concatenados — la tarjeta pedía
explícitamente "un solo paste", no dos bloques para armar a mano.

**Sigue pendiente de correr** — no tengo forma de generar la imagen yo
mismo. Cuando el usuario tenga créditos, es ese bloque único, tal cual,
sin editar.

**Cómo se interpreta el resultado, ya acordado con el coordinador** (para
no tener que decidirlo de nuevo cuando llegue la imagen):
- **Si pasa** (silueta y color de firma se leen bien a 26px): mismo
  preámbulo corregido se usa para el resto del catálogo de 20 sin más
  ajustes de estilo.
- **Si vuelve a fallar el color de firma puntualmente** (no la silueta, no
  el detalle pintado — específicamente el color): ya no es un problema de
  prompt. Sería evidencia de que el color de firma de esta torreta en
  particular (blanco/gris claro) tiene poco contraste inherente contra
  cualquier outline+sombra a 26px, y ahí correspondería replantear el
  criterio de color por torreta (`docs-torretas-diseno.md`), no otra
  ronda de prompt.
- Motor está probando en paralelo, sin depender de este resultado, si
  `mipmaps/generate=true` explica parte de la pérdida de nitidez
  (`smoke-test-motor-arte-v1.md` sección 9) — dato complementario, no
  sustituye la ronda 3.
