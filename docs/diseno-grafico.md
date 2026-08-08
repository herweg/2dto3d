# Dirección de arte espacial — paleta cerrada, estilo y VFX pendientes de benchmark GPU

**Estado:** propuesta abierta — pendiente de benchmark de GPU y decisión del director.
**Rol:** Dirección de Arte (voz nueva en este proceso; no existía como rol separado
hasta este documento — hasta ahora las decisiones con componente visual las tomaba o
aprobaba el director, ver `fase2-motor-cristalizado.md`).
**Responde a:** las dos tareas que el Auditor asignó al equipo de gráficos (sprite/
animación en paralelo; arte de las 20 torretas cuando el diseño en papel avance), más
el pedido de evaluar la temática espacial y la viabilidad de `docs/reference-assets/`.
**Fecha:** 08-ago-2026.

---

## 0. Qué cambia respecto al encargo original

El encargo era producir el prompt final para generar el arte 2D en ChatGPT. Al bajar a
tres decisiones concretas — técnica de ilustración, paleta, y nivel de riesgo de VFX —
quedó claro que **la técnica de ilustración depende de una variable que todavía no se
midió**: cuánto cuesta en GPU (Vega 56) el tipo de partículas/shaders que este
documento propone para la capa de "caos" del catálogo de 20 torretas. Comprometer un
estilo ahora, sin saber si esa capa termina resuelta con sprites pre-dibujados o con
partículas reales, arriesga producir arte que no calza con el pipeline final — el
volumen de arte estático a mano cambia mucho según qué camino gane (ver sección 4).

Así que este documento no cierra con un prompt. Cierra con lo que sí se pudo decidir
(paleta, sección 1), la evaluación de viabilidad pedida (secciones 2 y 3), y una
propuesta de benchmark concreta (sección 5) para que el director la evalúe y decida
cómo seguir. Es el mismo patrón que ya usó este proyecto para el spike de Rust y el
benchmark conjunto: medir antes de comprometer el plan.

---

## 1. Paleta y mood — cerrado: "Industrial fronteriza"

Base: metal oxidado, placas remachadas, roca oscura/regolito, sombras que caen casi a
negro. Es la dirección más cercana al material ya reunido en
`docs/reference-assets/look-n-feel/` (las tres capturas de *Defense Grid: The
Awakening*) — puesto de avanzada minero en el borde del espacio, no nave nueva y
reluciente.

**Regla dura, no negociable:** el fondo/terreno nunca compite en saturación con la capa
de juego. Esta es la constante que se repite sin excepción en las 7 imágenes de
referencia que revisamos (`docs/reference-assets/`, ambas carpetas): el camino se
distingue del terreno por contraste de valor, no de detalle; las torres llevan un halo
de color saturado que las separa del entorno; los enemigos, aun siendo la amenaza,
nunca son más brillantes que la respuesta del jugador.

**Importante — esto es la paleta del *entorno*, no la de las 20 torretas.**
`docs-torretas-diseno.md` ya fijó un color de firma único por torreta (blanco/gris
acero, naranja quemado, cian eléctrico, violeta, amarillo, lima, verde bosque, rojo,
rojo oscuro, celeste, verde tóxico, azul eléctrico, púrpura, dorado, magenta, gris con
rojo, blanco con dorado, y la paleta completa recorriéndose en la torreta del Caos) —
veinte colores que tienen que convivir legibles a la vez. La paleta industrial
fronteriza es el escenario oscuro y neutro donde esos veinte colores actúan; **no le
suma acentos cian/naranja propios a las torretas ni a los enemigos** — los reserva para
elementos estructurales (halo de base de torre genérica, zona construible, indicadores
de UI) para no competir con el sistema de firma que ya está diseñado. Si el entorno
también gritara en cian y naranja, la mitad del catálogo de 20 (los que ya son
cian/naranja: riel, perforante) perdería su ancla visual.

**Continuidad con lo ya aprobado — cámara y pose.** `game/assets/characters.png`
(placeholder heredado del POC, aprobado técnicamente en el commit `67a9165` para el
mecanismo de swap de textura, no evaluado nunca como arte final) está dibujado en vista
3/4 lateral — personajes de cuerpo entero mirando hacia la derecha, pintado semi-
realista, grid 5×5 (fila = tipo de personaje, columna = idle/caminar/atacar/ranged/
muerto). Confirmé en `entity_render_sync.gd` que hoy **no hay rotación, flip ni escala
por instancia** — todas las transformaciones son identidad salvo posición — así que
cualquier personaje queda siempre dibujado mirando en la misma dirección sin importar
hacia dónde camine. Dos maneras válidas de convivir con esa restricción, ninguna
requiere tocar motor:
1. Mantener la convención 3/4 lateral y aceptar el mismo matiz cosmético que ya tiene
   hoy el placeholder (el personaje "mira" siempre igual).
2. **Diseñar los enemigos con siluetas sin dirección marcada** — criaturas/drones
   flotantes, radialmente simétricos o ambiguos de frente — con lo que el problema
   desaparece por diseño, no por motor. Encaja naturalmente con temática alienígena
   (enjambres, drones, formas orgánicas sin "adelante" obvio) y es upgrade gratis sobre
   el placeholder actual. **Es mi recomendación** — no necesita validación del director,
   es una decisión de contenido, no de arquitectura.

**Nota técnica para quien arme las hojas finales:** `characters.png` es 1024×1024 con
grid 5×5 — 1024÷5 = 204.8px, no entero, y `SpriteAtlas.crop_frame()` arrastra ese
redondeo (confirmado leyendo `sprite_atlas.gd`). Las hojas nuevas deberían usar una
grilla que divida exacto (p. ej. 1000×1000 a 5 columnas = 200px, u 8×8 = 128px) para no
heredar el mismo defecto de recorte.

**Nota técnica sobre cuántos tipos distintos entran en pantalla a la vez:** hoy cada
store de render (`MultiMeshInstance2D`) muestra una sola textura para todas sus
instancias — variedad real entre tipos requiere un store por tipo, no una hoja con
muchas variantes mezcladas en un mismo store (`fase2-stress-test.md`, addendum).
Con torres topeando en ~20-24 y un margen de rendimiento de 40× en ese eje, 20 stores de
torre (uno por tipo, cada uno con su color de firma ya pintado en el sprite en vez de
aplicado por tinte en runtime) es barato — el costo de `MultiMesh` está en la cantidad
de *instancias* por store, no en la cantidad de *stores*. Esto confirma que el catálogo
de 20 colores de firma es alcanzable con la arquitectura actual, sin esperar el sistema
de UV-por-instancia que quedó descartado por ahora (`directorsuggestions.md` 2.3). Sí
hace falta un ajuste chico de motor, fuera de este documento: `EntityRenderSync.sync()`
hoy vuelca todas las posiciones en un único buffer sin enrutar por `type_id` a stores
distintos — para tener 20 stores de torre hace falta esa ruta. Lo anoto como tarjeta de
motor pendiente, no como bloqueante de arte.

---

## 2. Viabilidad de la temática espacial (planetas/lunas/estrella)

**Veredicto: viable, recomendada, y no depende del benchmark de la sección 5.** Un
fondo de nivel es una imagen estática (o a lo sumo un par de capas de parallax) —
costo de GPU trivial en cualquier hardware, incluida una Vega 56, y no tiene relación
con el debate de partículas/shaders de este documento. La `estrella` final tampoco
introduce ningún costo especial por sí misma — es paleta y composición, no simulación.

**Lo que sí falta, y es de motor, no de arte:** `LevelDef` (`game/data/level_def.gd`) es
hoy, por diseño explícito de su propio comentario de cabecera, "geometría pura, sin
arte" — `path_rects`, `waypoints`, `obstacles`, `buildable_zones`, nada de fondo ni
tema visual. `Level1.tscn` no tiene `TileMap` ni `Sprite2D` de ambiente en absoluto; el
carril se dibuja hoy como un rectángulo verde sólido vía `_draw()`. No hay dónde
enganchar un fondo todavía — hace falta un campo nuevo en `LevelDef` (una textura o un
enum de tema) más el nodo que la dibuje detrás de las entidades. Es una tarjeta de
ingeniería chica y separada, no bloquea producir el arte ahora mismo.

**Progresión sugerida** (plantilla reusable, no un conteo final de pantallas — ese
número no está definido en ningún documento del proyecto todavía):

| Pantalla (ejemplo) | Tema | Palabra clave de paleta |
|---|---|---|
| 1 | Luna helada, puesto minero de entrada | grises azulados, hielo, primer contacto |
| 2 | Planeta rocoso/desértico | ocres, cañones, tormentas de polvo |
| 3 | Luna/jungla alienígena | orgánico, bioluminiscencia controlada (sin romper la regla de la sección 1) |
| 4 | Gigante gaseoso, plataforma orbital | nubes densas, relámpagos atmosféricos a lo lejos |
| 5 (clímax) | Superficie/corona de una estrella | ver nota de contraste abajo |

**Nota de contraste para la estrella:** una corona estelar "correcta" (blanco-dorado,
sobreexpuesta) rompe la regla de la sección 1 — competiría en brillo con los 20 colores
de firma. Se resuelve igual que en las referencias de Defense Grid (que también tienen
focos muy brillantes sin perder el resto de la lectura): oscurecer y desaturar el fondo
jugable (plasma rojo oscuro/magenta profundo en vez de blanco puro, viñeta hacia los
bordes) y reservar el blanco-dorado cegador para el horizonte/silueta, no para el
área donde se juega. Mismo principio que ya aplican las 3 capturas de referencia, no
una regla nueva.

Si más adelante se quiere que la estrella tenga peligro de *gameplay* (daño de fondo,
llamaradas periódicas) y no solo ambientación, eso es diseño de combate + motor, no
arte — lo dejo anotado para no mezclarlo con este documento.

---

## 3. Qué es reproducible hoy de `docs/reference-assets/`, y qué no

**De `look-n-feel/` (Defense Grid: The Awakening):**

Adoptable ya, costo cero, no depende del benchmark: la paleta/mood (es la base de la
sección 1), el halo de color saturado marcando la base de cada torre, el contraste de
valor camino/terreno, la jerarquía "las torres del jugador siempre más grandes y más
brillantes que la amenaza". El acabado 3D-renderizado en sí **no es el pipeline** —
ChatGPT genera imágenes 2D planas, no modelos con iluminación dinámica, y ese nivel de
detalle se pierde igual a los ~14-26px de render actuales (`level_controller.gd`,
`stress_main.gd`) — no hace falta perseguirlo ni es una pérdida no perseguirlo.

Lo que **sí** es exactamente el terreno en discusión en la sección 4, con ejemplo
concreto de la propia imagen de referencia:

- Burbujas translúcidas de escudo sobre grupos de enemigos (imágenes 2 y 3) — alpha
  blending superpuesto, varias instancias a la vez.
- Arco eléctrico ramificado (imagen 3) — geometría que cambia según qué enemigos están
  en rango ese frame.
- Explosiones grandes con muchas partículas simultáneas + bloom (imágenes 2 y 3).

**De `hitboxes/`:** esta carpeta mezcla estilos deliberadamente distintos (confirmado —
un mapa vectorial plano, un juego voxel/casual, un mockup de UI aislado, y un
screenshot más), así que no se lee como referencia de acabado sino de *conceptos* de
indicador, todos adoptables ya sin costo ni dependencia del benchmark:

- Círculo con relleno hachurado para marcar rango/área de efecto (imagen del mapa
  vectorial) — el ejemplar más limpio del set.
- Cono de disparo de bordes suaves como indicador implícito de dirección/impacto
  (las dos capturas del juego voxel).
- Código de color consistente por función/tipo (el mockup de torreta + 4 barras de
  color) — ya está resuelto en el catálogo de 20 torretas de `docs-torretas-diseno.md`,
  esta imagen es la confirmación visual de que el criterio es correcto.

---

## 4. El caso para VFX con GPU real — argumentos

No todo lo que "se ve caro" pide lo mismo. Separando el catálogo de 20 torretas
(`docs-torretas-diseno.md`) por qué tipo de costo pide cada efecto, quedan tres
categorías distintas — y la propuesta de benchmark de la sección 5 solo necesita
cubrir una de ellas:

**Geometría procedural (línea/segmento) — ya probada barata, no necesita el
benchmark.** Rayo en Cadena (#14, líneas quebradas conectando N enemigos, cambia cada
frame según quién está en rango) y el hilo de carga de Riel (#3) son casos de dibujo
vectorial dinámico, no de partículas — la misma categoría que ya usa hoy
`level_controller.gd` para pintar carril y zonas construibles vía `_draw()`. Es CPU
construyendo geometría simple + GPU rasterizando líneas; no hay precedente de que esto
sea caro en este proyecto porque, de hecho, ya está en producción.

**Tinte/hue-shift — probablemente barato, vale medirlo pero no bloquea nada.** Torreta
del Caos (#20, recicla el color de las otras 19 en cada disparo) es el caso de libro
para un shader simple de modulación de color sobre una única malla — mucho más barato
que mantener 19 variantes de sprite pre-coloreadas por separado. Lo incluyo como
corrida chica dentro del mismo benchmark (sección 5), pero no es el riesgo real.

**Partículas y overdraw alpha — esto es lo que hay que medir.** Enjambre (#6, ráfaga de
3-5 proyectiles pequeños que se desperdigan y convergen — "lluvia de meteoritos" a
stats máximos) y Gravedad (#15, remolino de partículas siendo absorbidas) son, por
diseño, sistemas de muchos elementos pequeños con movimiento individual — exactamente
lo que un sprite pre-dibujado en loop no logra transmitir de forma convincente, y
exactamente lo que un `GPUParticles2D` resuelve con un solo emisor. Fuego (#11) y
Veneno (#13) son el caso de overdraw por acumulación: "humo negro acumulado si hay
muchas zonas activas" / "nube tóxica que contagia" — efectos translúcidos que se
apilan. Este último caso ya tiene un límite hermano del lado de simulación: `PROJ_ZONE`
capa en `ZONE_FIXED_COUNT := 10` (`fase2-benchmark-conjunto.md`) precisamente porque
"pocas zonas activas a la vez" es la premisa de diseño — el benchmark de VFX debería
respetar ese mismo tope como punto de partida, no uno arbitrario.

**Nota de honestidad, para no vender esto de más:** la técnica de ilustración de los
cuerpos estáticos (torres, enemigos) no depende técnicamente del costo de partículas —
un sprite plano cuesta lo mismo sea vectorial, pintado o pixel art. Lo que sí cambia
según qué gane en la sección 5 es el *volumen* de arte estático a producir a mano: si
VFX termina en sprites pre-dibujados, hay que ilustrar bastantes más estados por
torreta (una serie por nivel de intensidad); si gana partículas/shaders reales, esos
estados los genera el motor y el trabajo de ilustración se concentra en los cuerpos.
Esa es la razón real para resolver ambas decisiones juntas, no una dependencia técnica
estricta.

---

## 5. Propuesta de benchmark GPU (los "tests" pedidos)

> **Benchmark de costo de VFX en GPU — Vega 56, desde cero.**
>
> Punto de partida: hoy no hay un solo `GPUParticles2D`, `Particles2D` ni shader
> custom en todo el proyecto (confirmado por lectura completa de `game/render/`,
> `game/sim/` y `game/rust/src/lib.rs`) — esto no extiende una medición anterior, es la
> primera de esta categoría de costo.
>
> Reusa la configuración de `fase2-benchmark-conjunto.md` como piso (2.400 enemigos,
> ~3.400-3.500 proyectiles mezcla realista, 24 torres reales, backend nativo — ya en
> 58-65fps *sin* ningún VFX todavía) y agrega una sola variable por corrida, mismo
> método que ya separó Ruta A/B y que aisló el problema de `PROJ_ZONE`:
>
> 1. **Costo unitario:** un emisor de partículas aislado (Enjambre o Gravedad a stats
>    máximos) replicado al conteo simultáneo realista para ese tipo de torreta.
> 2. **Escenario objetivo real:** "30 torretas maxeadas disparando junto" — la frase
>    textual de `docs-torretas-diseno.md` — con varios efectos VFX candidatos a la vez,
>    no uno solo aislado.
> 3. **Overdraw dirigido:** N instancias superpuestas de un efecto translúcido (fuego/
>    veneno acumulado), arrancando en el mismo tope que ya usa `PROJ_ZONE`
>    (`ZONE_FIXED_COUNT := 10`) y una corrida adicional por encima de ese tope para
>    saber cuánto margen real hay antes de que duela.
> 4. **Corrida chica de control:** el shader de tinte de Torreta del Caos, para
>    confirmar que efectivamente es barato y no hace falta tratarlo con la misma
>    cautela que 1-3.
>
> Umbral: 60fps con el mismo margen del 20% de T4 ya usado en todo el proyecto.
> Salida esperada: tabla de frametime por escenario, mismo formato que
> `fase2-benchmark-conjunto.md`, para que el director decida con el mismo criterio que
> ya usó ahí.

---

## 6. Pedido explícito de cierre, dirigido al director

Para poder generar los prompts finales de ChatGPT en la siguiente pasada, necesito de
vuelta:

1. ~~Greenlight (o ajuste) del benchmark de la sección 5~~ — **hecho, 08-ago**:
   `docs/fase2-vfx-benchmark.md`. Costo fijo real (~7-10fps de promedio, ~11-15fps de
   piso) por tener VFX presente, pero **no escala con cuánto se agrega** — 3 emisores
   cuestan lo mismo que 20+10, y overdraw ×10 lo mismo que ×25. No es el riesgo que
   había que temer, con datos en vez de argumento.
2. **Con el resultado en mano, la elección de técnica de ilustración** entre las tres
   candidatas (vectorial plano de bordes marcados, pintado semi-realista evolucionando
   `characters.png`, o pixel art retro) — el benchmark ya no las bloquea, siguen las
   tres abiertas como decisión de diseño; en la sección 0 de este documento están las
   razones por las que no elijo una sin el dato.
3. **Confirmación de que la tarjeta de motor de la sección 1** (enrutar `sync()` por
   `type_id` a un store por tipo) y **la de la sección 2** (campo de fondo/tema en
   `LevelDef`) entran al tablero como trabajo de motor pendiente, no de gráficos —
   ninguna de las dos bloquea lo que sigue listo hoy (sección 7).

---

## 7. Qué queda listo para ejecutar ya, sin esperar nada de lo anterior

- **Paleta "industrial fronteriza"** (sección 1) — cerrada.
- **Dirección temática espacial y progresión de pantallas** (sección 2) — cerrada,
  incluida la resolución de contraste para la estrella final.
- **El catálogo de 20 torretas está confirmado desbloqueado para arte.** La condición
  que puso el propio Auditor ("cuando el diseño en papel avance") ya se cumplió — el
  diseño en papel cerró en el commit `8b75cb9` ("Cierra la tarjeta de diseño en papel
  de las 20 torres"). 16 de las 20 todavía no tienen fila en `TOWER_TYPE_STATS`; de
  esas 16, al menos 13 (Riel, Mortero, Racimo y Enjambre por nombre propio, más las 9
  de categorías D/E/F) piden `proj_type` o lógica nueva en `projectile_system.gd` según
  la propia nota de reconciliación del auditor al final de `docs-torretas-diseno.md` —
  las otras 3 (Francotiradora, Serpiente, Fuego) no están flageadas ahí y podrían
  alcanzar con fila nueva + `proj_extra`, a confirmar cuando alguien haga ese triage.
  En cualquier caso es bloqueo de *simulación*, no de arte — se puede ilustrar una
  torreta sin que su comportamiento esté implementado todavía.
- Lo único que falta para escribir los 20+ prompts finales es la técnica de
  ilustración (sección 6, punto 2). En cuanto esté, la producción arranca directo —
  sujeto, colores de firma, paleta de entorno y composición ya están decididos en este
  documento.

---

## 8. Respuesta del director a los tres pedidos de la sección 6 (08-ago)

Buen documento — la paleta cerrada, la regla dura de contraste, y sobre
todo separar el catálogo de 20 en las tres categorías de costo de VFX
(geometría procedural / tinte / partículas-overdraw) antes de pedir un solo
benchmark, es exactamente el criterio correcto: no medir todo por igual
porque "parece caro".

**1. El benchmark de la sección 5: greenlight, con una condición de
secuencia.** El diseño en sí no lo toco — reusa `fase2-benchmark-conjunto.md`
como piso, aísla una variable por corrida, mismo método de siempre. Pero ese
piso tiene un problema propio ahora mismo: encontré un bug real en la
revisión de código de esa misma corrida (`tick_native()` destruía zonas/
misiles vivos por error) y el 58-65fps que reportaba **no queda validado**
— ver la sección nueva que agregué en `fase2-benchmark-conjunto.md`. No
tiene sentido medir el costo de partículas encima de un presupuesto CPU que
todavía no se confirmó sólido — si el número base se mueve al re-correrlo,
la lectura del benchmark de VFX se movería con él sin que nadie lo note.
**Orden: re-confirmar el piso primero, después el benchmark de la sección
5** — no cambia el diseño de ninguno de los dos, solo el orden. Quien lo
corre: confirmo que sigue siendo el rol de motor/director, como todos los
anteriores — misma persona que ya tiene el arnés y los benchmarks previos
a mano.

**2. Técnica de ilustración:** de acuerdo en dejarla abierta hasta tener el
dato — no la fuerzo ahora. Se resuelve en la misma pasada que el punto 1.

**3. Las dos tarjetas de motor: confirmadas, entran al tablero.**
- Enrutar `EntityRenderSync.sync()` por `type_id` a un store por tipo — necesario
  para que las 20 torretas tengan su sprite propio. Con 40× de margen ya
  medido en el eje de torres, no le veo riesgo de rendimiento — es trabajo
  de plomería, no una apuesta.
- Campo de fondo/tema en `LevelDef` — igual de directo, costo de GPU trivial
  como ya evaluaste en la sección 2.

Ninguna de las dos compite con el resto del trabajo de motor en curso — se
pueden hacer en cualquier momento libre, no hace falta priorizarlas contra
el benchmark de VFX ni contra la re-confirmación del piso.

**Un pendiente que encontré yo, no ustedes, y que les toca a los dos
lados.** `fase2-plan-proyectiles.md` (sección 5) señala que el catálogo de
20 torretas no tiene una fila que se llame "Láser" — lo más cercano por
nombre es Riel, que ya confirmamos que es un mecanismo distinto. Antes de
que la elección de técnica de ilustración se convierta en 20+ prompts
concretos, alguien tiene que reconciliar nombres: Riel ≠ Láser (confirmado),
pero Mortero/Misil y Fuego/Lanzallamas todavía no está dicho si son el mismo
concepto renombrado o si son cuatro entradas distintas — no lo resuelvo yo
acá, es una decisión de diseño, no de arte ni de motor. La dejo marcada para
que no se descubra recién al escribir el prompt de la fila 5, 6 o 9.

---

## 9. Técnica de ilustración — decidida (director, 08-ago, post-VFX)

El benchmark de la sección 5 salió — `docs/fase2-vfx-benchmark.md`: costo
fijo por tener VFX presente, no escala con cuánto se agrega, piso de motor
absorbe ese costo con margen en el rango probado. Ya no bloquea nada. Con
eso resuelto, esto es lo último que faltaba para que Arte escriba los 20+
prompts finales.

**Descarto pintado semi-realista** (evolucionar `characters.png`) — no por
gusto, por un número que ya está en el código: los quads de render en este
proyecto miden entre 14 y 26px (`level_controller.gd`, `stress_main.gd`,
`typed_render_group.gd`). El detalle pintado de `characters.png` está
pensado para leerse mucho más grande que eso — a 14-26px, un torso con
sombreado y textura de tela se va a leer como una mancha de color, no como
una silueta reconocible. Esto empeora, no mejora, con el problema que la
propia sección 1 ya identificó: 20 colores de firma que tienen que
distinguirse a simple vista y en simultáneo. Pintado detallado compite
contra su propia legibilidad a este tamaño; no es un problema de VFX ni de
GPU, es geometría de píxeles en pantalla.

**Elijo vectorial plano de bordes marcados** sobre pixel art retro — los
dos leen bien a 14-26px, la diferencia está en el pipeline de producción
que ya está en marcha. El catálogo de 20 torretas (`docs-torretas-diseno.md`)
ya está descripto enteramente en el vocabulario de "color de firma plano +
silueta clara" — vectorial plano es ejecutar ese vocabulario tal cual, sin
traducirlo. Pixel art pide además sostener una grilla de píxel consistente
entre 20+ generaciones independientes por prompt de ChatGPT — un eje de
consistencia adicional que el pipeline actual (un prompt por torreta/
enemigo, no un spritesheet armado a mano) no está pensado para verificar.
No es que pixel art no funcione — es que vectorial plano tiene un riesgo de
producción menos para este pipeline específico.

**Esto es una llamada técnica de legibilidad + ajuste de pipeline, no un
veto de gusto.** Si Arte tiene una razón de diseño fuerte para pixel art
que yo no esté viendo, listo para escucharla — pero no la bloqueo más
tiempo esperando esa conversación si no hay una objeción concreta ya
planteada.

**Con esto, Arte tiene luz verde para escribir los 20+ prompts finales y
producir textura real** — paleta, colores de firma, composición, temática
espacial y ahora técnica de ilustración están cerrados. El pendiente de
nomenclatura (Mortero/Misil y Fuego/Lanzallamas, ya reconciliados en
`docs-torretas-diseno.md`/`tower_store.gd`; si láser tiene entrada propia o
la absorbe Riel, todavía abierto) no bloquea empezar — se resuelve por
torreta a medida que se prompta, no antes.
