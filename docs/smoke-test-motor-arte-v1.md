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
