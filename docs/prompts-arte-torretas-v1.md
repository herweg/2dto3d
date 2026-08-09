# Prompts de producción — 7 torretas sin ambigüedad + entornos (v1)

**Estado:** listo para producir — 08-ago-2026.
**Rol:** Dirección de Arte.
**Responde a:** tarjetas 1, 3, 5 y 6 del coordinador sobre `docs/diseno-grafico.md`.
Tarjeta 2 (Láser) y tarjeta 4 (enemigos) están tratadas al final, sin prompts —
ver sección D.

**Qué es esto, exactamente.** Este documento no genera imágenes — no tengo una
herramienta de generación de imágenes en este entorno. Cada bloque de código
debajo de un encabezado en negrita (`**Cuerpo**`, `**Base**`, etc.) es texto
listo para pegar en ChatGPT tal cual, uno por vez (cada imagen es un pedido
separado). Los prompts están en inglés a propósito
— es el idioma con el que los modelos de generación de imágenes responden con
mayor fidelidad a instrucciones de estilo; el resto del documento (contexto,
justificación, notas para motor) está en español, igual que el resto de `docs/`.

Decisiones que ya están cerradas y que este documento simplemente ejecuta —no
hay nada para decidir acá, ver `docs/diseno-grafico.md` secciones 1 y 8-9:
técnica (vectorial plano, bordes marcados), paleta de entorno (industrial
fronteriza), 20 colores de firma (`docs/docs-torretas-diseno.md`), grilla
entera para hojas nuevas (evitar el defecto de `characters.png`), libertad de
presupuesto en la capa "máxima" (`docs/fase2-vfx-benchmark.md`).

---

## A. Preámbulo de estilo — pegar antes de cada prompt de torreta/VFX (sección B)

**Revisado 09-ago, tras el smoke test (`docs/smoke-test-motor-arte-v1.md`
secciones 7-8, veredicto "no pasa").** La versión anterior pedía "bold,
clean dark outlines (consistent line weight)" — eso, no solo la falta de
anclaje flat, es lo que causó el fallo #2 (color de firma: a 26px el negro
del line-art dominaba sobre el gris acero del cuerpo). El ajuste de ronda 3
que había quedado pendiente en `qa-prueba-assets-v1.md` sección 5 punto 2
(flat fills, sin gradiente/AO/especular/bisel/desgaste) está fusionado acá
directo en el preámbulo — aplica a las 20 torretas, no solo a la que falló
el test, así que se corrige una vez acá en vez de pegarse aparte en cada
prompt de acá en más.

```
2D game asset, flat vector illustration / sticker-icon style — solid flat
color fills only, no shading gradients, no ambient occlusion, no specular
highlights, no drop shadow, no bevel, no weathering or grunge texture
noise. Think flat mobile-game icon, not a rendered 3D asset. Thin, minimal
outline only where needed to separate the silhouette from the background —
the outline must be visually secondary to the fill: never heavier or
darker-and-thicker than the flat fill color, because the fill color (not
the outline) is what has to read as the turret's signature color at a
glance. 2-3 flat color tones maximum. Strong, simple, instantly readable
silhouette designed to read clearly at very small on-screen size (roughly
20-40px tall in the final game — the real in-game render is 26px).
Elevated 3/4 side view (not top-down, not full side profile), static
neutral pose, no implied walking or facing direction. A stationary
ground-mounted weapon emplacement bolted to its base, like a fixed
artillery/gun turret — NOT a robot, NOT bipedal, NOT a humanoid mech or
character, no legs, no arms, no face. Rugged industrial sci-fi
frontier-outpost material language: worn rusted metal, riveted armor
plating, weathered dark surfaces, exposed rivets and panel seams — NOT
clean/pristine sci-fi, NOT organic or biological. Transparent background
(PNG alpha). No ground shadow baked in, no text, no watermark, no UI, no
frame or border. Square canvas, subject centered, filling about 70-75% of
frame height.
```

**Agregar además en los prompts de proyectil/impacto base y medio
específicamente** (cuerpo de torreta no — ahí el detalle de remaches/panel
suma, en el proyectil chico sobra): `Keep it extremely simple — 2-3 flat
shapes maximum, no rivets, no panel lines, no glossy highlights, no
gradients. It will be viewed at 10-20px on screen, smaller than a fingertip
on the reference canvas — any fine detail added here is wasted and reads
as noise, not detail.` Ronda 1 (`docs/try-assets/`) salió consistentemente
más detallada/brillosa de lo pedido en ambas herramientas — ver
`docs/qa-prueba-assets-v1.md`.

**Canvas y spec de producción (tarjeta 3):** 1024×1024px, fondo transparente,
un asset por imagen — no pedir a ChatGPT que arme una grilla/spritesheet
(los generadores de imagen no sostienen grillas de celda pareja de forma
confiable entre 20+ generaciones separadas; armar la hoja final es un paso de
post-proceso aparte, no un pedido de prompt). Si en algún punto se arma una
hoja de animación (torres no lo necesitan hoy — son estáticas, "las torres no
se destruyen en v1", `tower_store.gd`), usar una grilla entera: 1000×1000 a 5
columnas = 200px, u 8×8 = 128px — nunca repetir el 1024÷5=204.8px de
`characters.png`.

---

## B. Las 7 torretas sin ambigüedad de nombre

Cada torreta tiene 4 entregables: el cuerpo (1 imagen estática — las torres no
rotan ni se destruyen en v1) y 3 capas de proyectil/impacto (base/medio/
máximo, principio general en `docs-torretas-diseno.md`). Marco cada capa con
cómo se implementa en motor, porque no todas son sprites:

- **`[sprite]`** — imagen estática, se pega tal cual.
- **`[sprite animado 2f]`** — 2 fotogramas, mismo mecanismo de swap de textura
  ya aprobado (`67a9165`) — pedir las 2 imágenes por separado, incluyendo el
  número de frame en el prompt para mantener consistencia entre ambas.
- **`[textura de partícula]`** — imagen chica y simple, se usa como textura
  base de un emisor `GPUParticles2D` (validado en `fase2-vfx-benchmark.md`,
  costo fijo, no escala con cantidad) — no dibujar la escena completa, solo
  la unidad que se repite.
- **`[geometría, sin arte]`** — línea/segmento dibujado en runtime
  (`draw_line`/`Line2D`), mismo mecanismo ya en producción en
  `level_controller.gd` para el carril — no hace falta generar imagen.

### 1. Torreta Recta — `type_id 0` — color de firma: blanco/gris acero

Mecánica: dispara al más cercano en línea recta, sin corrección. Máx stats:
cadencia tan alta que se lee como línea punteada continua — el "caos" acá es
ritmo de disparo, no partícula nueva.

**Cuerpo `[sprite]`**
```
A compact fixed defense turret, boxy angular chassis on a short tripod
base, a single forward-facing autocannon barrel, steel-grey and off-white
metal plating with dark grey mechanical joints, a thin glowing pale
steel-white (#C9D3D8-ish) rim-light tracing the silhouette edge and a
small steel-white indicator light on the chassis. No other color accents.
```

**Ronda 3 — prompt único, preámbulo + cuerpo ya fusionados (tarjeta Arte,
commit `737b11a`).** El smoke test de motor (`docs/smoke-test-motor-arte-v1.md`
secciones 7-8) encontró que a 26px reales el color de firma no se leía —
causa raíz: el preámbulo viejo pedía "bold, clean dark outlines", y eso
enterraba el gris acero bajo el line-art, independiente del detalle
pintado. El preámbulo de la sección A ya está corregido (outline fino y
secundario al relleno). Este bloque es el mismo cuerpo de arriba con el
preámbulo nuevo ya pegado — un solo paste, no hace falta armar el
concatenado a mano:
```
2D game asset, flat vector illustration / sticker-icon style — solid flat
color fills only, no shading gradients, no ambient occlusion, no specular
highlights, no drop shadow, no bevel, no weathering or grunge texture
noise. Think flat mobile-game icon, not a rendered 3D asset. Thin, minimal
outline only where needed to separate the silhouette from the background —
the outline must be visually secondary to the fill: never heavier or
darker-and-thicker than the flat fill color, because the fill color (not
the outline) is what has to read as the turret's signature color at a
glance. 2-3 flat color tones maximum. Strong, simple, instantly readable
silhouette designed to read clearly at very small on-screen size (roughly
20-40px tall in the final game — the real in-game render is 26px).
Elevated 3/4 side view (not top-down, not full side profile), static
neutral pose, no implied walking or facing direction. A stationary
ground-mounted weapon emplacement bolted to its base, like a fixed
artillery/gun turret — NOT a robot, NOT bipedal, NOT a humanoid mech or
character, no legs, no arms, no face. Rugged industrial sci-fi
frontier-outpost material language: worn rusted metal, riveted armor
plating, weathered dark surfaces, exposed rivets and panel seams — NOT
clean/pristine sci-fi, NOT organic or biological. Transparent background
(PNG alpha). No ground shadow baked in, no text, no watermark, no UI, no
frame or border. Square canvas, subject centered, filling about 70-75% of
frame height.

A compact fixed defense turret, boxy angular chassis on a short tripod
base, a single forward-facing autocannon barrel, steel-grey and off-white
metal plating with dark grey mechanical joints, a thin glowing pale
steel-white (#C9D3D8-ish) rim-light tracing the silhouette edge and a
small steel-white indicator light on the chassis. No other color accents.
```

**Base `[sprite]`** — corregido tras ronda 1 (ver
`docs/qa-prueba-assets-v1.md`): salió con remaches y brillo especular pese
al pedido de "minimalist", agrego la cláusula de simplificación explícita
del preámbulo directo en el cuerpo del prompt, no solo por referencia:
```
A tiny simple bullet/dart projectile, one solid flat shape, pale
steel-white color (#C9D3D8-ish), no gradient, no glossy highlight, no
rivets or panel lines, a short flat motion-blur streak behind it, no
glow, no particles. Keep it to 2-3 flat shapes maximum — it will be
viewed at 10-20px on screen.
```

**Medio `[sprite]`** — misma corrección:
```
Same tiny flat steel-white bullet/dart as a straight tracer round, no
gradient, no glossy highlight, now with a short soft flat glowing trail
streak behind it fading to transparent, pale steel-white color. Keep it
to 2-3 flat shapes maximum — it will be viewed at 10-20px on screen.
```

**Máximo `[geometría, sin arte]`** — a esta cadencia el proyectil se
convierte visualmente en una línea punteada continua; es repetición de la
capa "medio" a alta frecuencia, no un asset nuevo. No genera prompt.

---

### 2. Torreta Homing — `type_id 1` — color de firma: amarillo

Mecánica: proyectil guiado, reapunta si pierde blanco. Máx stats: estela
curva tipo cometa, retarget instantáneo sin frenar.

**Cuerpo `[sprite]`**
```
A compact fixed defense turret, boxy angular chassis on a short tripod
base, a small rotating radar/seeker dish mounted above a narrow twin-barrel
launcher, dark steel-grey metal plating, a thin glowing warm saturated
yellow (#F4C430-ish) rim-light tracing the silhouette edge and a small
yellow indicator light on the seeker dish. No other color accents.
```

**Base `[sprite]`**
```
A tiny simple homing missile/dart projectile, solid warm saturated yellow
color (#F4C430-ish), slight motion-blur streak behind it, no glow, no
particles, minimalist.
```

**Medio `[sprite]`**
```
Same tiny yellow homing dart, now trailing a short soft curved glowing
trail fading to transparent, warm saturated yellow color, still
minimalist, no particles.
```

**Máximo `[sprite]`**
```
A small elongated comet-tail trail shape, teardrop silhouette, bright
saturated yellow (#F4C430-ish) core fading through translucent
yellow-white to fully transparent at the tail end, smooth curved taper,
no background, meant to be stretched and rotated along a curved flight
path in-engine.
```

---

### 3. Torreta Perforante — `type_id 2` — color de firma: naranja quemado

Mecánica: atraviesa varios enemigos en línea (proj_extra = impactos). Máx
stats: el proyectil se agranda visualmente por cada perforación (escala en
motor, no arte nuevo) y al morir dispara una mini onda expansiva naranja.

**Cuerpo `[sprite]`**
```
A compact fixed defense turret, boxy angular chassis on a short tripod
base, a single reinforced long-barrel cannon with visible muzzle
venting, dark rusted steel plating, a thin glowing burnt orange
(#C2551E-ish, deep warm orange) rim-light tracing the silhouette edge and
a small burnt-orange indicator light on the chassis. No other color
accents.
```

**Base `[sprite]`**
```
A small solid dart/slug projectile, elongated aerodynamic shape, solid
burnt orange color (#C2551E-ish), slight motion-blur streak behind it,
no glow, no particles, minimalist.
```

**Medio `[sprite]`**
```
Same small burnt-orange dart/slug projectile, now with a soft glowing
orange halo surrounding it that grows slightly toward the back, still
minimalist, no particles.
```

**Máximo — impacto final `[sprite animado 2f]`** (el agrandado del
proyectil en sí es un `scale` en motor, no un asset nuevo — solo el
estallido final necesita arte):
```
Frame 1 of 2: a small expanding ring shockwave, thin bright burnt orange
(#C2551E-ish) ring outline on transparent background, ring at about 40%
of final size, sharp and bright.

Frame 2 of 2: same expanding ring shockwave shape, burnt orange
(#C2551E-ish), now at 100% size, outline thinner and fading toward
transparent, same style and center point as frame 1.
```

---

### 4. Torreta Splash — `type_id 3` — color de firma: rojo

Mecánica: daño de área al impactar. Máx stats: anillo de onda expansiva +
partículas de escombros saltando hacia afuera.

**Cuerpo `[sprite]`**
```
A compact fixed defense turret, boxy angular chassis on a short tripod
base, a stubby wide-bore mortar-like barrel, dark heavy steel plating
with visible blast shielding, a thin glowing saturated red (#D62828-ish)
rim-light tracing the silhouette edge and a small red indicator light on
the chassis. No other color accents.
```

**Base `[sprite]`**
```
A small round explosive shell projectile, solid saturated red color
(#D62828-ish), slight motion-blur streak behind it, no glow, no
particles, minimalist.
```

**Medio `[sprite]`**
```
Same small red round explosive shell, now with a soft glowing red halo
trailing behind it, faint short trail, still minimalist, no particles.
```

**Máximo — onda expansiva `[sprite animado 2f]`:**
```
Frame 1 of 2: a small expanding ring shockwave, thick bright saturated
red (#D62828-ish) ring outline on transparent background, ring at about
40% of final size, sharp and bright, slight orange-white hot core at
center.

Frame 2 of 2: same expanding ring shockwave shape, saturated red
(#D62828-ish), now at 100% size, outline thinner and fading toward
transparent, same style and center point as frame 1.
```

**Máximo — escombros `[textura de partícula]`:**
```
A single tiny irregular debris chip/fragment, dark grey rock/metal shard
with a thin glowing red (#D62828-ish) edge highlight, simple flat shape,
meant to be emitted in large numbers by a particle system, no background.
```

---

### 5. Torreta de Riel — `type_id 7` (RAIL) — color de firma: cian eléctrico

Mecánica: carga 1-2s, luego hitscan instantáneo que atraviesa toda la línea,
ignora armadura. Visual: hilo de carga + flash de rayo grueso. Máx stats:
anillo pulsante durante la carga, rayo dobla de grosor con línea residual.

**Cuerpo `[sprite]`**
```
A compact fixed defense turret, boxy angular chassis on a short tripod
base, a long thin precision rail-barrel with visible coil/capacitor rings
along its length, dark steel plating, a thin glowing electric cyan
(#22E2F0-ish, saturated bright cyan) rim-light tracing the silhouette
edge and a small cyan indicator light on the chassis. No other color
accents.
```

**Carga (base/medio) `[geometría, sin arte]`** — el hilo de carga que crece
desde la torreta es una línea dibujada en runtime (`Line2D`/`draw_line`),
mismo mecanismo que el carril — no genera prompt de imagen.

**Núcleo del rayo, todas las capas `[textura de partícula]`** (una sola
textura, estirada/engrosada en motor según la capa — máx stats la dobla de
grosor, no hace falta un asset nuevo):
```
A short horizontal beam segment texture, bright electric cyan
(#22E2F0-ish) hot white-cyan core fading to transparent cyan at the top
and bottom edges, soft glow, meant to be stretched horizontally as a
laser beam core, no background.
```

**Máximo — anillo de carga pulsante `[sprite animado 2f]`:**
```
Frame 1 of 2: a thin pulsing ring, electric cyan (#22E2F0-ish) outline
on transparent background, ring at about 80% size, bright and sharp.

Frame 2 of 2: same thin ring shape, electric cyan (#22E2F0-ish), now at
100% size, outline slightly softer/glowing, same style and center point
as frame 1 — meant to loop back and forth during the charge-up.
```

---

### 6. Torreta de Mortero — `type_id 4` (misil en código) — color de firma: rojo oscuro / marrón

Mecánica: arco parabólico con delay de vuelo notorio a la zona de mayor
densidad. Máx stats: cráter marcado un instante + 2-3 fragmentos secundarios
que también explotan.

**Cuerpo `[sprite]`**
```
A compact fixed defense turret, boxy angular chassis on a short heavy
tripod base, a short thick angled mortar tube pointed upward, dark
oxidized rust-brown metal plating with heavy rivets, a thin glowing dark
red-brown (#5C2018-ish, oxide red-brown) rim-light tracing the
silhouette edge and a small dull red indicator light on the chassis. No
other color accents.
```

**Proyectil, todas las capas `[sprite]`** (el mismo cuerpo vale para las 3
capas — lo que cambia entre capas es la sombra/cráter/fragmentos, no el
proyectil en sí):
```
A small round heavy mortar shell projectile viewed from a 3/4 elevated
angle, solid dark red-brown color (#5C2018-ish) with a slightly darker
underside, no glow, no particles, minimalist, meant to arc through the
air with a simple drop-shadow drawn separately underneath it in-engine.
```

**Máximo — cráter `[sprite]`:**
```
A circular scorched crater decal, dark red-brown (#5C2018-ish) burnt
ground mark fading to transparent at the edges, flat top-down view,
meant to be placed on the ground and fade out after a moment, no
background.
```

**Máximo — fragmentos secundarios `[textura de partícula]`:**
```
A single tiny simple round fragment/ember shape, dark red-brown
(#5C2018-ish) core with a small bright orange-red glowing highlight,
simple flat shape, meant to be emitted a few at a time flying outward
from an impact point, no background.
```

---

### 7. Torreta de Fuego — `type_id 5` (lanzallamas en código, familia BEAM) — color de firma: rojo-naranja con capa de fuego

Mecánica: rectángulo de daño continuo (DoT) frente a la torre, no proyectil
individual. Máx stats: se propaga levemente a enemigos adyacentes al morir
dentro, humo negro acumulado si hay muchas zonas activas.

**Cuerpo `[sprite]`**
```
A compact fixed defense turret, boxy angular chassis on a short tripod
base, a wide short-barreled flame projector nozzle with visible fuel
tanks on its sides, dark scorched steel plating, a thin glowing
red-orange (#E24A1E-ish) rim-light tracing the silhouette edge with a
small warm orange indicator light on the chassis. No other color
accents.
```

**Parche de fuego en el suelo, base/medio `[sprite animado 2f]`** (mismo
mecanismo de swap idle/walk ya aprobado — acá es un ciclo de parpadeo del
fuego, no de caminata):
```
Frame 1 of 2: a small flat patch of ground fire, irregular flame shape
viewed from a 3/4 elevated angle, gradient from deep red-orange
(#E24A1E-ish) at the base to bright yellow-orange (#FFB347-ish) at the
flame tips, soft glow, transparent background.

Frame 2 of 2: same ground fire patch, same footprint and colors
(#E24A1E-ish to #FFB347-ish), flame tips shifted slightly to one side to
read as a subtle flicker when alternated with frame 1, same style, no
background.
```

**Máximo — humo acumulado `[textura de partícula]`:**
```
A single soft round smoke puff, dark grey-black translucent blob with a
soft feathered edge, low opacity, simple flat shape, meant to be emitted
slowly upward and accumulate when many fire patches are active at once,
no background.
```

---

## C. Entornos — progresión de pantallas (tarjeta 5)

**Nota de motor, no bloquea producir esto:** `LevelDef` todavía no tiene
campo de fondo (`docs/diseno-grafico.md` sección 2, tarjeta confirmada por
el director en la sección 8) — coordinar con Mesa de Developers el orden de
esa tarjeta; el arte se produce igual, queda esperando el enganche.

**Canvas:** 1920×1080px, fondo opaco (sin transparencia), sin personajes ni
torres ni UI dibujados encima — solo el escenario. Todas comparten la regla
dura de `docs/diseno-grafico.md` sección 1: el fondo nunca compite en
saturación con la capa de juego — valores oscuros/medios, acentos saturados
solo como puntos de interés pequeños y aislados, nunca de campo completo.

**Preámbulo de estilo — pegar antes de cada prompt de esta sección:**
```
2D game background illustration, flat vector illustration style matching
a bold-outlined flat-shaded game art style (not painterly, not
photorealistic). Wide establishing view of a rugged industrial sci-fi
frontier outpost built into the terrain. Overall dark-to-mid value range,
desaturated or muted base colors — this is a backdrop meant to sit behind
saturated colorful gameplay elements, so it must stay visually quiet and
never compete for attention. Any bright accents are small, isolated
points of light, not broad washes. No characters, no turrets, no UI, no
text, no foreground path markings. Widescreen canvas.
```

### 1. Luna helada — puesto minero de entrada

```
An icy moon surface at dusk, pale blue-grey rock and packed ice, a
small weathered mining outpost structure in the distance with a few
scattered warm artificial lights, thin drifting ice-fog near the ground,
cold blue-grey overall palette, dark shadowed crevices.
```

### 2. Planeta rocoso/desértico

```
A dusty rust-ocre desert planet surface, deep wind-carved canyons, dry
cracked ground, a faint dust storm haze on the horizon, warm ochre and
dark brown palette kept muted and shadowed rather than bright.
```

### 3. Luna/jungla alienígena

```
An alien jungle moon surface, dark dense organic vegetation with
twisted alien plant silhouettes, a few small isolated points of soft
bioluminescent teal-green glow scattered in the undergrowth, overall
dark desaturated green-black palette, damp low-lying mist.
```

### 4. Gigante gaseoso — plataforma orbital

```
A metal orbital platform floating above a gas giant, heavy industrial
scaffolding and support struts in the foreground, the gas giant's dense
banded clouds filling the background in muted muddy oranges and greys,
a few faint distant lightning flashes deep within the cloud bands, dark
overall value.
```

### 5 (clímax) — superficie/corona de una estrella

Nota de contraste (`docs/diseno-grafico.md` sección 2): una corona "correcta"
es blanco-dorado cegador — se oscurece y desatura deliberadamente el área
jugable y se reserva el blanco-dorado real para el horizonte/silueta, para no
competir con los 20 colores de firma.

```
A stylized stellar surface/corona scene, deep dark red and magenta plasma
in the mid-ground and foreground kept dark and desaturated rather than
blindingly bright, with a searing white-gold blinding glow strictly
confined to the far horizon line and background silhouette only, subtle
dark solar-flare filament shapes in the background, strong vignette
darkening toward the edges and center-bottom where gameplay would sit.
```

---

## D. Qué queda afuera de esta tanda, y por qué

**Torreta Láser (`type_id 6`) — pausada, tarjeta 2.** Está implementada en
motor (`tower_store.gd`, familia BEAM, rectángulo angosto y largo) pero
todavía no tiene resuelto si es una entrada propia del catálogo de 20 o si
Riel la reemplaza (`docs/diseno-grafico.md` sección 8, nota del director). No
genero prompt para no producir arte de una torreta que puede no existir como
tal en el catálogo final — en cuanto diseño lo resuelva, es la misma
plantilla que las 7 de arriba, con su propio color de firma a definir.

**Enemigos — tarjeta 4 aprobada, sin roster para promptear todavía.** La
tarjeta aprueba el *criterio* (siluetas sin dirección marcada, drones/
criaturas radialmente simétricas, en vez de la convención 3/4 lateral fija de
`characters.png`) — eso queda confirmado y es la regla a aplicar en cuanto
haya algo que dibujar. Pero a diferencia de las torretas, **no existe ningún
catálogo de enemigos espaciales** en `docs/` — ni nombres, ni cantidad de
arquetipos, ni mecánica, ni color de firma. Las 20 torretas pudieron
promptearse hoy porque `docs-torretas-diseno.md` ya había hecho ese trabajo de
diseño primero; los enemigos todavía no tienen su propio equivalente. No lo
invento acá por mi cuenta — es diseño de contenido/combate, no de arte, el
mismo límite de rol que ya marcó `docs/diseno-grafico.md` para la
reconciliación de nombres. Lo dejo marcado como el próximo hueco a llenar,
para que no se descubra recién cuando alguien pida el primer enemigo
espacial.
