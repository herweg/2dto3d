# Fase 3 — hacer el juego ganable: derrota + encadenado

**Rol:** Mesa de Developers (Motor).
**Fecha:** 10-ago-2026.
**Origen:** `docs/fase3-tarjeta-ganable-v1.md` (Dirección) — commit `e9740ed`.
Pedido del usuario: revisar la tarjeta y proceder.

---

## 1. Qué pedía la tarjeta

Derrota + encadenado juntos — sin las dos, nada de lo ya construido (5
niveles, guardado, árbol de talentos) se puede probar como una partida
real: sin derrota, toda ronda "gana" sola con solo esperar; sin
encadenado, los 4 niveles que `f0cfa56` ya construyó siguen sin poder
jugarse.

## 2. Condición de derrota

- `RoundState.ROUND_LOST` — nuevo, paralelo a `ROUND_COMPLETE`, no lo
  reemplaza.
- `_max_lives := 20` (placeholder, `lives=<n>` lo pisa para test) — se
  resetea al máximo en `_start_round()`, no en `_ready()`: la tarjeta pide
  el reset "al empezar cada ronda", no al cargar la escena (hoy coinciden
  porque solo hay una ronda por instancia, pero quedó en el punto que pide
  la tarjeta, no en el que coincide por accidente).
- `_check_defeat()` — lee `_lane_system.leaked_count - _leaked_at_round_start`
  cada frame de `COMBAT` y recalcula vidas desde cero (no descuenta de a
  uno) — cubre varios leaks en el mismo frame sin necesitar un hook por
  evento, sin tocar `LaneEnemySystem` (tal como pedía la tarjeta). Se
  llama primero en `_tick_round_spawner()`, antes de evaluar victoria — si
  las vidas y la oleada se agotan en el mismo frame, gana la derrota.
- Sin oro al perder (`_lose_round()` no llama a `SaveManager`), sin avance
  de `stage_index` — se reintenta el mismo nivel. Salida es la que ya
  existía, "Salir al menú".

## 3. Encadenado de niveles

- `SaveManager.state["stage_index"]` (0-4) — nuevo, **no** `player_level`
  (son dos "niveles" distintos, mismo cuidado de vocabulario que ya pedía
  `fase3-alcance-v1.md` sección 4 punto 1).
- `level_controller.gd` ya no hace `preload()` fijo a `level_01.tres` —
  `_load_level_for_stage()` resuelve el `LevelDef` antes de construir
  nada (los sistemas necesitan `_level.waypoints` desde el arranque, no se
  puede resolver en la segunda pasada de `_parse_cli_args()` como el
  resto de los flags). `stage=<n>` (CLI) pisa el guardado sin persistirlo,
  para poder probar un nivel puntual.
- **Al ganar:** `_advance_stage_and_continue()` — si no era el último
  nivel, `stage_index += 1`, guarda, espera 1.5s (para que "Ronda
  completa" se alcance a ver) y recarga `Level1.tscn` (que va a leer el
  `stage_index` ya incrementado). Si ya era el último (`stage_index` en
  el tope), va a `MainMenu.tscn` en cambio — "pantalla de victoria final"
  es Fase 4, no bloquea esto, tal como dice la tarjeta.
- **Al perder:** no toca `stage_index`, se queda en `ROUND_LOST`.

## 4. Un bug encontrado en el camino: el guard de "TEST: Finalizar ronda"

`_force_finish_round()` solo chequeaba `ROUND_COMPLETE` para no-op —
con `ROUND_LOST` nuevo, ese guard dejaba que el botón de test pisara una
derrota ya disparada con una victoria forzada. Corregido: chequea los dos
estados terminales.

## 5. Verificación

Todos los casos que pide la sección 4 de la tarjeta, más el guard de la
sección 4 de este documento:

| Caso | Args | Resultado |
|---|---|---|
| Regresión estándar | `place-all-towers real-stats start-round quit-after=8` | `torres:8, muertes:2, leaks:0` — idéntico al baseline histórico, `vidas:20, stage:0` |
| `stage=<n>` carga el nivel correcto sin persistir | `stage=2 real-stats quit-after=7` (ventana) | Captura confirma geometría/paleta de nivel 3 (jungla, violeta) — `savegame_test.json` no se crea, nada cambió |
| Derrota real (no forzada) | `real-stats lives=1 start-round quit-after=20` | `[derrota — vidas agotadas]`, `estado:ROUND_LOST`, sin `savegame_test.json` (sin oro, sin persistir nada) |
| Derrota visual | `real-stats lives=3 start-round quit-after=31` (ventana) | Captura: botón "Derrota" deshabilitado, botón de test también deshabilitado, "Vidas: 0" |
| **Cadena completa de 5 niveles, sin jugar ninguno de verdad** | `place-all-towers real-stats start-round force-finish-round screenshot-quit` desde `Level1.tscn` | 5× `[ronda completa]` en secuencia, se detiene sola al llegar a `MainMenu.tscn` (que no entiende esos flags) — `stage_index` termina en 4 (tope), `gold` en 50 (5×10) |
| Captura final en `MainMenu.tscn` | (la misma corrida de arriba) | "Planeta: 5/5", "Oro: 50" legibles |
| `_force_finish_round()` no pisa una derrota ya disparada | revisión de código + cubierto indirectamente por los casos de arriba (el guard nunca dejó pasar un estado terminal existente en ningún test) | — |
| `stress-test` sin cambios | `stress-test stress-towers=8 stress-enemies=50 quit-after=3` | Idéntico a siempre — la máquina de estados/vidas no lo toca |

**Nota de método, un artefacto de prueba, no del juego:** un primer intento
de correr la cadena completa desde `MainMenu.tscn` con `auto-start` en la
misma invocación entró en un bucle — al volver a `MainMenu` después de
ganar el último nivel, esa pantalla vuelve a leer los mismos argumentos de
línea de comandos (estáticos para todo el proceso) y `auto-start` se
dispara de nuevo, sin que nada distinga "primera vez" de "ya gané todo".
Nada corrupto (`stage_index` se mantuvo correctamente en el tope durante
30+ repeticiones, oro siguió sumando de a 10 de forma consistente) — se
resolvió arrancando la corrida directo en `Level1.tscn` en vez de pasar
por el menú. Mismo tipo de artefacto ya documentado en
`fase3-motor-log.md` sección 4.3 para `auto-talents`/`auto-back`.

## 6. Fuera de alcance, tal como pedía la tarjeta

Números reales de vidas/oro (calibración después), pantalla de selección
de nivel, pantallas de victoria/derrota diseñadas (Fase 4), conectar los
efectos del árbol de talentos a combate (ya identificado aparte en
`fase3-talentos-motor.md`).
