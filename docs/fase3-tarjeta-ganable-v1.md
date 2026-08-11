# Tarjeta — hacer el juego "ganable": derrota + encadenado de niveles

**Rol:** Dirección de Desarrollo.
**Fecha:** 10-ago-2026.
**Origen:** pregunta directa de la PM (¿concatenar niveles o popularlos
primero?) — verifiqué el estado real antes de responder, no asumí.

## 0. Por qué la pregunta ya tiene media respuesta, verificada en el código

**Popular ya está hecho.** `f0cfa56` construyó y verificó los 4 niveles que
faltaban (planeta rocoso, jungla alienígena, gigante gaseoso, estrella) —
los 5 `LevelDef` existen. Lo que confirmé que **no** existe:

1. **Ningún selector/encadenado real** — el commit lo dice explícito:
   "ninguno de los 4 está conectado todavía, `level_01.tres` sigue siendo
   el único cargado". `level_controller.gd` sigue con un `preload()`
   fijo, no elige nivel según progreso.
2. **Ninguna condición de derrota.** `RoundState` es
   `{PLACEMENT, COMBAT, ROUND_COMPLETE}` — `_complete_round()` siempre
   otorga oro, sin chequear nada. Sin forma de perder, "ganable" tampoco
   se puede probar de verdad: toda ronda "gana" trivialmente con solo
   dejar pasar el tiempo, cero riesgo real.

Por eso coincido con la PM: no es en realidad "concatenar o popular" —
popular ya terminó. Lo que falta, y lo que hace al juego jugable de punta
a punta, es **derrota + encadenado juntos** — sin las dos, nada de lo que
ya está construido (5 niveles, guardado, árbol) se puede probar como una
partida real.

## 1. Condición de derrota

- **Vidas del jugador** — contador simple, valor placeholder (ej. 20,
  **no calibrado, a ajustar en la calibración de combate que ya viene
  después**). Se resetea al máximo al empezar cada ronda — no se
  arrastra entre niveles (una racha mala en el nivel 2 no te condena en
  el 3, mismo criterio que la mayoría de los TD).
- Cada enemigo que llega a la meta descuenta 1 vida — `LaneEnemySystem`
  ya trackea `leaked_count`; alcanza con leer el delta desde el inicio de
  la ronda, sin tocar `LaneEnemySystem`.
- **`RoundState.ROUND_LOST`** — nuevo valor del enum, paralelo a
  `ROUND_COMPLETE` (no lo reemplaza). Se dispara cuando las vidas llegan
  a 0 durante `COMBAT`, antes de que se agote la oleada. Sin oro al
  perder — se puede reconsiderar en calibración, no ahora.

## 2. Encadenado de niveles

- **Campo nuevo en `SaveManager`: `stage_index`** (0-4) — **no
  `player_level`**, a propósito: son dos "niveles" distintos
  (`fase3-alcance-v1.md` sección 4 punto 1 ya marcó la confusión de
  vocabulario como algo a evitar). `stage_index` = qué planeta alcanzaste;
  `player_level` sigue siendo la meta-progresión de slots de torre, sin
  tocar acá.
- `level_controller.gd` deja de hacer `preload()` fijo a `level_01.tres`
  — carga el `LevelDef` que corresponda a `SaveManager.state["stage_index"]`
  (mapeo simple índice→ruta de los 5 `.tres` ya construidos).
- **Al ganar** (`ROUND_COMPLETE`, vidas > 0): `stage_index += 1` (tope 4,
  el último), persistido, y avanza directo al siguiente nivel — no hace
  falta una pantalla de selección todavía, la progresión es lineal
  (mismo orden temático ya diseñado). Ganar la estrella (nivel 5, índice
  4) vuelve a MainMenu — "pantalla de victoria final" queda para Fase 4,
  no bloquea esto.
- **Al perder** (`ROUND_LOST`): no avanza `stage_index` — reintenta el
  mismo nivel la próxima vez. Mismo camino de salida que ya existe
  ("Salir al menú"), sin pantalla de derrota diseñada todavía (Fase 4).

## 3. Fuera de alcance, a propósito

Número real de vidas y de oro perdido/ganado (placeholder, calibración
después), pantalla de selección de nivel (la progresión lineal alcanza
para probar que el juego es ganable de punta a punta), pantalla de
victoria/derrota con diseño, conectar los efectos del árbol de talentos a
combate (ya identificado como pendiente aparte en
`fase3-talentos-motor.md`).

## 4. Verificación esperada

Mismo criterio CLI del resto del proyecto: forzar derrota (agotar vidas
sin agotar la oleada), completar los 5 niveles en secuencia sin jugar de
verdad cada uno (`force-finish-round` ya existe), confirmar que
`stage_index` persiste entre procesos (mismo patrón ya usado para oro/
talentos en `fase3-guardado-motor.md` sección 5), y la regresión estándar
completa sin cambios.
