# Referencia de diseño — captura de pantalla de un tower-defense de horda

**Estado: RECONCILIADO (07-ago-2026), FORMALIZADO (08-ago-2026)** — ver
`sprint-02.md`, sección "Insumo adicional reconciliado", para la resolución
original de los tres puntos abiertos de más abajo, y la firma compartida en
el punto 2 para el registro formal que faltaba. `definicion-escala-v1.md` no
se modificó en cuanto al modelo de juego — T2 (el número) queda igual, con
nota explícita de por qué; T4 (hardware) sí se actualizó el 08-ago por una
razón no relacionada, ver ese documento.
**Por qué este documento existió separado antes de hoy:** llegó mientras el
equipo estaba en medio de Ruta B (GDExtension) — no correspondía tocar
alcance ni código mientras esa implementación estaba en curso. Quedó anotado
aparte para no perderse, y se resolvió recién cuando Ruta B cerró.

---

## Lo que muestran las dos capturas

Dos momentos del mismo juego de referencia, aportado como inspiración para el
producto:

- **Captura 1 (early game):** ~168 enemigos vivos, 214 muertos acumulados.
  Dos "torres" — vehículos/estructuras fijas con su propia arma — disparando
  hacia un frente de enemigos que avanza por un pasillo de terreno entre
  paredes de roca.
- **Captura 2 (fase avanzada):** **23.585 enemigos vivos simultáneos**, 4.182
  muertos acumulados. Cuatro torres fijas visibles, cada una dañada/con vida
  propia (barras rojas sobre las torres), disparando hacia una masa de
  enemigos que satura buena parte de la pantalla.

---

## Tres implicancias de diseño, independientes del número

### 1. Torres como entidades fijas, no arma-sobre-jugador

El jugador no lleva las armas encima (como hoy el POC, con `weapon_*.gd`
como hijos de `Player`) — coloca puntos de disparo fijos en el mapa. Cada
torre tiene su propio rango, cooldown y (por las barras de vida visibles en
la captura 2) posiblemente su propia vida/destructibilidad.

### 2. Enemigos en flujo por un camino, no convergencia radial al jugador

En ambas capturas los enemigos avanzan por un corredor entre paredes, de un
punto A a un punto B — no convergen en círculo hacia una posición central
como hace `enemy.gd`/`enemy_system.gd` hoy (`to_anchor := anchor -
position`, seek directo). Es esteo por camino/carril (waypoints o flow
field), y el jugador decide dónde poner las torres a lo largo de ese camino,
no está parado en medio del enjambre.

### 3. Variedad de torres ≠ variedad de entidades en código

Confirma, no contradice, el patrón ya elegido: igual que `enemy.gd` usa
`TYPE_STATS` y el roster de 13 comportamientos de `projectile-variety-v1.md`
usa `type_id` sobre un mismo array plano, distintas torres pueden ser filas
de datos distintas sobre un mismo `TowerStore`, no clases separadas. No hace
falta decidir esto ahora — se resuelve con el mismo criterio ya validado.

---

## El riesgo técnico real, y el único que vale la pena señalar ahora

La captura 2 muestra **~23.585 enemigos vivos simultáneos** — muy por encima
del objetivo cerrado en T2 (**1.500–2.000, pico 3.000**). Si en algún momento
esto se toma como referencia de *escala real* a perseguir (no solo de
mecánica de juego), rompe la asimetría en la que se apoya `spatial_hash.gd`
hoy: la grilla se construye sobre el lado barato (enemigos, miles) porque
son muchos menos que los proyectiles (decenas de miles). Si los enemigos
también escalan a decenas de miles, esa asimetría desaparece y el diseño de
la grilla — sobre qué población se construye, con qué frecuencia — hay que
reconsiderarlo desde cero, no solo reescalar constantes.

No es un problema para resolver ahora. Es la razón concreta por la que este
documento no toca `definicion-escala-v1.md`: cambiar T2 en caliente, en
medio de un spike que está midiendo contra el número actual, invalidaría la
medición de Ruta A y movería el objetivo debajo de Ruta B a mitad de camino.

---

## Postura que se mantuvo mientras Ruta B estaba en curso (histórico)

- Ruta B siguió exactamente como estaba planeada, sin cambio de alcance ni
  de número objetivo — el spike midió contra T2 tal como estaba cerrado.
- No se tocó código mientras el trabajo de Ruta B estaba en curso.
- Este documento fue la anotación formal de que el insumo había llegado, para
  que no dependiera de la memoria de nadie llegar al checkpoint de Fase 2.

## Resolución (07-ago-2026) — ver `sprint-02.md`, Paso 6, para el detalle

1. **Número de T2: no se revisa.** Ver razonamiento completo arriba — un
   precedente adicional de mecánica de juego no es lo mismo que evidencia de
   que la arquitectura sostiene enemigos en ese orden de magnitud, y esto
   último ni se midió. Si se persigue en serio más adelante, es un spike
   nuevo, no una actualización de este documento.
2. **Torres fijas + enemigos en carril: adoptado para Fase 2.**

   > **Documentado por: Auditor (revisión retroactiva, 08-ago-2026).
   > Autorizado por: PM (08-ago-2026).**
   > Esta confirmación no quedó escrita en su momento — `fase2-motor-cristalizado.md`
   > y el commit `89fbbd9` (`TowerStore`, `LaneEnemySystem`, `level_01.tres`)
   > ya construyeron sobre este modelo, y el director firmó el checkpoint de
   > motor como si estuviera resuelto, sin que existiera acá el registro
   > explícito que este mismo documento pedía antes de arrancar contenido
   > real. La decisión de producto (adoptar torres+carril) fue del PM; esta
   > nota la deja escrita donde correspondía desde el principio, para que el
   > historial refleje lo que efectivamente se decidió y no dependa de
   > inferirlo del código.

3. **Rediseño de la grilla sobre ambas poblaciones: no aplica por ahora**,
   condicional a que el punto 1 (número de enemigos de T2) cambie en el
   futuro — sigue sin aplicar, el punto 1 no cambió.

Las tres quedan resueltas al 08-ago-2026 — ver también `sprint-02.md`,
sección "Insumo adicional reconciliado", para el razonamiento original de
cada una.
