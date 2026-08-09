# Diseño de torretas — catálogo de ~20 tipos

> Contexto: extiende las 4 torretas ya implementadas (`TOWER_TYPE_STATS` en `tower_store.gd`):
> `0` recta, `1` homing, `2` perforante, `3` splash.
> Este documento **no** define código ni balance numérico final — define comportamiento,
> lectura visual, y cómo cada torreta contribuye a que el juego se sienta cada vez más
> caótico a medida que sube de nivel/stats. Todo esto es material de referencia para
> implementarlo después como filas nuevas del mismo store (mismo patrón: `type_id` selecciona
> la fila, no se crean clases nuevas).

## Principio general de escalado al caos

Cada torreta tiene 3 "capas" de lectura visual según su nivel de stats:

- **Nivel base (mín. stats):** proyectil simple, un color, sin partículas extra.
- **Nivel medio:** el proyectil gana una estela o un segundo efecto (chispa, halo).
- **Nivel máximo:** el proyectil se vuelve un evento visual — deja rastro de color,
  genera partículas secundarias, puede spawnear mini-efectos hijos (chispas, fragmentos,
  ondas), y su impacto tiene micro-shake de cámara o flash de color. La idea es que con
  30 torretas maxeadas disparando junto, la pantalla se llene de colores distintos y
  el jugador lo lea como "estoy ganando en grande", no como ruido ilegible — para eso,
  **cada torreta tiene un color de firma único** que se mantiene en las 3 capas (solo cambia
  intensidad/tamaño, no la paleta), así el ojo puede seguir distinguiendo "esa explosión
  verde es de la torreta de veneno" incluso en medio del caos.

---

## Categoría A — Balísticas (evoluciones directas de recta/perforante)

### 1. Torreta Recta (ya existe — `type 0`)
- **Color de firma:** blanco/gris acero.
- **Mecánica:** dispara al enemigo más cercano en línea recta, sin corrección.
- **Máx stats:** el disparo deja una estela corta tipo trazadora; cadencia tan alta que
  suena a ametralladora y se ve como una línea punteada continua hacia el objetivo.

### 2. Torreta Perforante (ya existe — `type 2`)
- **Color de firma:** naranja quemado.
- **Mecánica:** atraviesa varios enemigos en línea (ya definida por `proj_extra` = nº de impactos).
- **Máx stats:** el proyectil se agranda visualmente cada vez que perfora (efecto "va
  acumulando masa"), y al morir dispara una mini onda expansiva naranja en el punto final.

### 3. Torreta de Riel (nueva)
- **Color de firma:** cian eléctrico.
- **Mecánica:** carga 1-2s antes de disparar, luego dispara un rayo instantáneo (hitscan)
  que atraviesa TODA la línea sin límite de impactos, ignora armadura.
- **Visual:** línea de carga (un hilo cian que crece desde la torreta) y luego un flash
  de rayo grueso que dura 2-3 frames. Máx stats: la carga emite un zumbido visual (anillo
  pulsante) y el disparo dobla de grosor, dejando la pantalla con una línea residual que
  se desvanece.

### 4. Torreta Francotiradora (nueva)
- **Color de firma:** violeta.
- **Mecánica:** rango enorme, cadencia muy baja, daño altísimo a un único objetivo
  (prioriza el enemigo con más vida en rango, no el más cercano).
- **Visual:** antes de disparar marca al objetivo con una mira violeta parpadeante;
  el disparo es una línea fina casi instantánea. Máx stats: el impacto crítico hace
  que el enemigo "explote" en partículas violeta si muere de ese golpe (kill visual
  distintivo, recompensa el one-shot).

---

## Categoría B — Guiadas / homing (evoluciones)

### 5. Torreta Homing (ya existe — `type 1`)
- **Color de firma:** amarillo.
- **Máx stats:** la estela se curva visiblemente detrás del proyectil (cola tipo cometa),
  y si pierde el objetivo (muere en el camino) retarget instantáneo a otro sin frenar.

### 6. Torreta Enjambre (nueva)
- **Color de firma:** amarillo-verdoso (lima).
- **Mecánica:** cada disparo lanza 3-5 proyectiles pequeños homing débiles en vez de uno
  fuerte — buena contra grupos, mala contra un solo objetivo tanque.
- **Visual:** ráfaga de puntitos que se desperdigan y luego convergen curveando hacia
  varios enemigos distintos. Máx stats: los puntitos dejan estelas finas que cruzan la
  pantalla como una lluvia de meteoros pequeños.

### 7. Torreta Serpiente (nueva)
- **Color de firma:** verde bosque.
- **Mecánica:** un único proyectil homing que, en vez de desaparecer al impactar, rebota
  al siguiente enemigo más cercano (como un "chain" pero viajando físicamente, no un rayo
  instantáneo) hasta N rebotes.
- **Visual:** el proyectil deja un rastro que se va curvando en zig-zag entre enemigos,
  como una serpiente de luz verde tejiendo el grupo. Máx stats: el rastro persiste 1-2s
  como una línea decorativa antes de desvanecerse, mostrando visualmente el camino que hizo.

---

## Categoría C — Área / splash (evoluciones)

### 8. Torreta Splash (ya existe — `type 3`)
- **Color de firma:** rojo.
- **Máx stats:** el radio de la explosión se dibuja con un anillo de onda expansiva que
  se expande y se desvanece, más partículas de "escombros" saltando hacia afuera.

### 9. Torreta de Mortero (nueva)
- **Color de firma:** rojo oscuro / marrón.
- **Mecánica:** dispara en arco parabólico (no en línea recta) a un punto del mapa con
  mayor densidad de enemigos, con delay de vuelo notorio — recompensa posicionamiento,
  penaliza objetivos que se mueven rápido.
- **Visual:** proyectil grande que sube y cae con sombra proyectada en el suelo (telegrafía
  dónde va a caer, útil para lectura). Máx stats: el cráter de impacto queda marcado un
  instante en el suelo y lanza 2-3 fragmentos secundarios que también explotan.

### 10. Torreta de Racimo (nueva)
- **Color de firma:** naranja brillante.
- **Mecánica:** el proyectil principal, al impactar, se fragmenta en 4-6 mini-proyectiles
  que salen disparados en abanico y explotan individualmente al segundo impacto.
- **Visual:** una explosión inicial pequeña seguida de un "estallido de fuegos artificiales"
  en abanico. Es de las torretas más vistosas en máx stats: llena la pantalla de mini-flashes
  naranjas encadenados.

### 11. Torreta de Fuego (DoT de área — nueva)
- **Color de firma:** rojo-naranja con capa de fuego.
- **Mecánica:** el impacto no hace mucho daño directo, pero deja el suelo ardiendo un
  tiempo (zona de daño continuo) que quema a cualquier enemigo que pase.
- **Visual:** parche de fuego animado en el suelo con partículas de humo subiendo. Máx
  stats: el fuego se propaga levemente a enemigos adyacentes cuando mueren dentro (efecto
  cadena de incendio), suma humo negro acumulado si hay muchas zonas activas — parte del
  "caos visual" de fondo.

---

## Categoría D — Estado / control (nuevas, dan variedad de *lectura*, no solo daño)

### 12. Torreta de Hielo
- **Color de firma:** celeste hielo.
- **Mecánica:** daño bajo, pero cada impacto aplica una ralentización acumulable; con
  suficientes impactos el enemigo queda congelado (stop total) unos segundos.
- **Visual:** el proyectil deja escarcha visual en el enemigo (overlay celeste), y al
  congelar del todo el sprite del enemigo se tiñe azul con cristalitos alrededor. Máx
  stats: enemigos congelados que reciben un golpe fuerte de otra torreta se "shatterean"
  (efecto rotura de cristal) — sinergia visual entre torretas.

### 13. Torreta de Veneno
- **Color de firma:** verde tóxico.
- **Mecánica:** poco daño directo, aplica un DoT (veneno) que se puede stackear varias
  veces en el mismo enemigo.
- **Visual:** nube verde pequeña alrededor del enemigo envenenado, más intensa según
  stacks. Máx stats: si un enemigo muere envenenado, explota en una nube tóxica que
  contagia veneno a los enemigos cercanos (propagación en cadena, muy vistoso en oleadas
  grandes).

### 14. Torreta de Rayo en Cadena
- **Color de firma:** azul eléctrico brillante.
- **Mecánica:** dispara un rayo instantáneo que salta de enemigo en enemigo (hasta N
  saltos), perdiendo algo de daño en cada salto.
- **Visual:** líneas eléctricas quebradas (zig-zag tipo relámpago) conectando varios
  enemigos a la vez, con un flash breve en cada nodo. Máx stats: más saltos + los nodos
  dejan chispas residuales; con varias torretas de este tipo la pantalla se llena de
  telarañas eléctricas azules cruzándose.

### 15. Torreta de Gravedad
- **Color de firma:** púrpura oscuro / negro con borde violeta.
- **Mecánica:** no hace daño (o hace poco); en vez de eso dispara un proyectil que al
  llegar crea un campo que atrae a los enemigos cercanos hacia el centro por un momento
  — pensada para agrupar enemigos y potenciar torretas de área.
- **Visual:** un "agujero" visual con distorsión/remolino de partículas siendo absorbidas
  hacia el centro. Máx stats: el campo deja una marca de anillo pulsante y, al terminar,
  suelta una pequeña onda expansiva que empuja para afuera (combo agrupar → explotar).

---

## Categoría E — Soporte / utilidad (no atacan directamente o atacan poco)

### 16. Torreta de Buff (Faro de Guerra)
- **Color de firma:** dorado.
- **Mecánica:** no dispara proyectiles; emite un aura de rango que aumenta cadencia o
  daño de las torretas cercanas.
- **Visual:** anillo dorado pulsante alrededor de la torreta, y las torretas afectadas
  reciben un leve brillo dorado en su base mientras están dentro del aura. Máx stats:
  el aura se agranda y pulsa más rápido, sincronizando visualmente los disparos de las
  torretas cercanas (refuerza la sensación de "sistema", no solo "más daño").

### 17. Torreta de Maldición
- **Color de firma:** magenta oscuro.
- **Mecánica:** dispara un proyectil que no hace daño pero marca al enemigo para que
  reciba más daño de TODAS las demás torretas por un tiempo (debuff, opuesto al buff #16).
- **Visual:** símbolo/aura magenta sobre el enemigo marcado. Máx stats: los enemigos
  marcados dejan un rastro de partículas magenta al moverse, fáciles de identificar como
  "prioridad" en medio del caos.

### 18. Torreta de Mina (colocación de área)
- **Color de firma:** gris con detalle rojo intermitente.
- **Mecánica:** en vez de disparar, "planta" minas invisibles en el rango que explotan
  al ser pisadas — pensada para zonas de paso obligado.
- **Visual:** pequeño parpadeo rojo apenas perceptible marcando la mina (telegrafiado
  sutil, no invisible del todo), explosión abrupta al activarse. Máx stats: explosión en
  cadena si hay varias minas cerca entre sí.

---

## Categoría F — "Ultra" / rareza alta, muy vistosas (para el clímax de caos)

### 19. Torreta Orbital (láser desde el cielo)
- **Color de firma:** blanco con destello dorado.
- **Mecánica:** cadencia muy baja, marca un punto del mapa y tras un delay cae un rayo
  vertical masivo desde arriba de la pantalla — daño altísimo en área pequeña.
- **Visual:** un círculo de marca en el suelo que se va llenando (telegrafía el impacto),
  luego un haz de luz vertical grueso con destello blanco que ilumina la pantalla un
  instante y deja humo. Es la torreta pensada para ser el "momento wow" ocasional entre
  el caos constante de las demás.

### 20. Torreta del Caos (aleatoria, tier final)
- **Color de firma:** cambia de color con cada disparo (recorre toda la paleta de las
  otras 19 torretas).
- **Mecánica:** cada disparo elige al azar el comportamiento de otra torreta de la lista
  (a veces splash, a veces homing, a veces rayo en cadena), con stats promedio.
- **Visual:** es literalmente el resumen del juego en una sola torreta — pensada para
  colocarse pocas unidades pero que su presencia garantice que siempre haya "algo
  distinto" pasando en pantalla. Buen remate temático para el pool de 20+.

---

### 21. Torreta Láser (nueva — resuelta 09-ago, arma separada de Fuego)
- **Color de firma:** rosa/fucsia brillante (propuesto — no colisiona con ningún
  color ya asignado de los 20 anteriores; ajustable si Arte prefiere otro al
  llegar a Fase 4, no hay canon previo que romper).
- **Mecánica:** misma familia que Torreta de Fuego (#11) — rectángulo de daño
  continuo (DoT) que parte de la torre, sin proyectil — pero es un **arma
  propia, no una variante de Fuego**: haz angosto y largo, DPS alto, tiempo de
  persistencia corto (`tower_store.gd`, fila 6, ya implementada y distinta de
  la fila 5 desde antes de esta decisión). Fuego es ancho/corto/DPS bajo/
  persistencia larga; Láser es lo opuesto en las cuatro dimensiones.
- **Visual:** haz de luz fino y continuo (no el parche de fuego animado en el
  suelo de Fuego). Sprite propio pendiente de Fase 4 — no bloquea nada de
  motor, la mecánica ya corre en la pantalla jugable real.

---

## Cómo se relaciona con lo ya implementado

- Todo esto sigue el mismo patrón de datos que `TOWER_TYPE_STATS`: cada torreta es una
  fila nueva con `range`, `fire_rate`, `damage`, `proj_type`, `proj_extra` — no hace
  falta clase nueva por torreta.
- Los `proj_type` existentes (`0` recto, `1` homing, `2` perforante, `3` splash) alcanzan
  para las categorías A, B y C tal cual, reutilizando `proj_extra` como ya se hace (nº de
  impactos / radio). Las categorías D, E y F (hielo, veneno, cadena, gravedad, buff/curse,
  minas, orbital, caos) necesitan `proj_type` nuevos en `projectile_system.gd` porque
  agregan comportamiento (aplicar estado, no dañar, afectar otras torretas) que los 4
  actuales no cubren — quedan fuera del alcance de este documento (que es solo diseño,
  no código), pero es la extensión natural cuando se decida implementarlas.
- El "modo desarrollo" (`DEV_RANGE_OVERRIDE` / `DEV_FIRE_RATE_OVERRIDE`) sirve igual para
  probar cada torreta nueva de forma aislada antes de calibrar.

> **Segunda revisión, 08-ago.** Cierra la tarjeta de "diseño en papel de las
> 20 torres" que tenía pendiente el PM — buen material, con criterio de
> lectura visual (color de firma por torreta) que no estaba pedido pero
> resuelve un problema real de legibilidad a 20+ torretas simultáneas.
>
> Un matiz técnico sobre el párrafo de arriba: "los `proj_type` existentes
> alcanzan para A, B y C tal cual" es más optimista de lo que muestra la
> descripción de varias entradas individuales. Al menos **Riel** (hitscan
> instantáneo sin límite de impactos, no un proyectil que viaja — distinto
> modelo de colisión que perforante), **Mortero** (trayectoria en arco con
> delay de vuelo, no línea recta), **Racimo** (spawnea proyectiles hijos al
> impactar — no es una fila, es una fila que genera más filas) y **Enjambre**
> (un disparo consume 3-5 entradas de `ProjectileStore`, no 1 — relevante
> para el presupuesto del benchmark de 3.000) piden lógica nueva en
> `projectile_system.gd`, no solo una fila nueva con `proj_extra` distinto.
> No es un problema del diseño — es información para cuando alguien haga el
> triage técnico de esta lista (el mismo ejercicio que
> `fase2-plan-proyectiles.md` ya hizo para básico/misiles/lanzallamas/láser),
> para no descubrirlo a mitad de implementación.
>
> Segundo punto, no técnico: no encuentro **"láser"** (el mecanismo con
> arquitectura pendiente de confirmar en `fase2-plan-proyectiles.md` 1.2) en
> este catálogo — lo más cercano por nombre es **Riel** (carga + hitscan), que
> es un mecanismo distinto al láser descrito ahí (DPS continuo mientras el
> enemigo está en el haz). Vale confirmar si el láser sigue en pie como
> torreta aparte, si Riel lo reemplaza, o si quedó afuera de este primer
> approach a propósito — no lo asumo en ninguna dirección.
>
> **Reconciliación de nombres, 08-ago (`fase2-benchmark-conjunto.md` sección
> 7).** Por correspondencia mecánica, no por suposición: **Mortero** (#9,
> arco parabólico + delay de vuelo + fragmentos secundarios) es lo que el
> motor viene llamando "misil" desde `fase2-plan-proyectiles.md` — mismo
> disparo (trayectoria precalculada al lanzar, splash al llegar), nombre
> distinto en cada documento. **Fuego** (#11, DoT de área que queda en el
> suelo) es lo que el motor llama "lanzallamas" — mismo mecanismo. Riel (#3)
> sigue confirmado distinto de láser, sin cambios ahí.
>
> **Resuelto, 09-ago.** Láser es arma propia del catálogo — **#21** arriba,
> misma familia mecánica que Fuego (rectángulo BEAM) pero configuración y
> sprite distintos, no una variante ni una entrada absorbida por Riel. Cierra
> la única pregunta de este párrafo que seguía abierta.
