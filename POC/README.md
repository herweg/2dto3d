# SimpleGame — Vampire Survivors POC (Godot 4.7)

POC de horde survivor para PC. Objetivo: validar arquitectura capaz de manejar
400–1000 enemigos a 60fps+ en GDScript puro.

---

## Estructura del proyecto

```
autoloads/
  GameManager.gd     — singleton: player_ref, kill_count, elapsed_time, señales
  WallManager.gd     — singleton: registro de Rect2 de paredes, push_out()

scenes/
  Main.tscn          — escena raíz: todos los sistemas como hijos de Node2D
  Player.tscn        — CharacterBody2D + Camera2D + OrbitWeapon
  Enemy.tscn         — CharacterBody2D invisible (rendering via MultiMesh)
  Projectile.tscn    — Area2D con trail via _draw()
  Wall.tscn          — StaticBody2D + CollisionShape2D + visual via _draw()
  HUD.tscn           — CanvasLayer con Labels conectadas a GameManager

scripts/
  main.gd            — input debug (F1 = +200 enemigos), scroll de fondo
  player.gd          — movimiento WASD, move_and_slide(), _draw() procedural
  enemy.gd           — movimiento directo, WallManager.push_out(), hit_flash
  enemy_pool.gd      — pool de 250 enemigos, spawn/return
  enemy_renderer.gd  — MultiMeshInstance2D central para todos los enemigos
  enemy_spawner.gd   — spawn en ring de 720u, intervalo acelerado cada 30s
  orbit_weapon.gd    — 4 orbes orbiting, disparo en cono via pool
  projectile.gd      — ring buffer para trail, body_entered para daño
  projectile_pool.gd — pool de 80 proyectiles
  wall.gd            — _draw() visual + registro en WallManager
  wall_spawner.gd    — 12 paredes en rango 280–1200u, call_deferred

shaders/
  background_grid.gdshader — tiling de textura scrolleable (player_pos uniform)

assets/
  grass_tile.png     — tile 600×600u para el fondo
```

---

## Mecanismos de performance

### MultiMeshInstance2D (enemies)
El mayor win de performance. En lugar de 400 `CharacterBody2D` dibujando
individualmente, un solo `EnemyRenderer` (Node2D) actualiza un `MultiMesh`
con la posición y color de cada enemigo activo cada frame. Resultado: 1 draw
call para todos los enemigos en lugar de 400.

### Movimiento directo sin move_and_slide() (enemies)
Los enemigos usan `global_position += direction * SPEED * delta` en lugar de
`move_and_slide()`. Esto elimina el narrowphase de PhysicsServer2D para 400+
cuerpos por frame. Los enemigos siguen siendo `CharacterBody2D` para que los
proyectiles puedan detectarlos via `body_entered` en su Area2D.

### Object pooling
- **EnemyPool**: 250 instancias pre-creadas, `visible = false`, `set_physics_process(false)`.
  `spawn()` activa la primera disponible. `return_enemy()` la desactiva.
  Guarda `dying` flag para no re-activar un enemigo en animación de muerte.
- **ProjectilePool**: 80 instancias. Mismo patrón.

### Ring buffer para trail de proyectiles
El trail de cada proyectil usa un array circular fijo de 6 posiciones en lugar
de `remove_at(0)` (que es O(n) por el shift). `_trail_head` avanza módulo 6.

### Caché de referencia directa al pool array
`orbit_weapon.gd` accede directamente a `_enemy_pool_ref._pool` (el Array interno)
en lugar de llamar `get_nodes_in_group("enemies")` cada frame, que aloca memoria.

### Physics cascade prevention
Sin `move_and_slide()` en enemigos, el frame budget se mantiene estable.
Cuando un frame excede el physics tick, Godot lo multiplica hasta 8×
— el fix de move_and_slide previene que una caída moderada se vuelva catastrófica.

---

## Colisión de paredes

### Jugador
`move_and_slide()` del Player detecta paredes automáticamente.
`collision_mask = 8` (layer 4 = wall). Sin código extra.

### Enemigos (AABB steering reactivo)
`WallManager` almacena `Array[Rect2]` de todas las paredes activas.
En cada frame, `enemy.gd` llama `WallManager.push_out(global_position, 12.0)`.

`push_out()` itera los Rect2, detecta overlap con el radio del enemigo via
distancia al punto más cercano del rect, y empuja la posición hacia afuera.
Con 400 enemigos × 12 paredes = 4800 comparaciones AABB por tick → sub-ms.

Comportamiento emergente: enemigos detrás de una pared se acumulan en su borde
y los que llegan en ángulo deslizan naturalmente. Sin A*, sin raycasts.

### Godot 4.7: call_deferred para add_child en _ready()
Las paredes se spawnan en `WallSpawner._ready()`. Si se usa `add_child(wall)`
directamente durante la fase ready del árbol, el `_ready()` del wall queda
en cola y puede no ejecutarse en el momento esperado. Solución:
`get_parent().call_deferred("add_child", wall)` — garantiza que `wall._ready()`
corre fuera de la fase de inicialización.

---

## Fondo scrolleable sin parallax

El fondo es un `ColorRect` en `CanvasLayer(-1)` (fijo en screen space).
Un shader lo convierte en un tile infinito:

```glsl
vec2 world = FRAGCOORD.xy + player_pos;
vec2 uv    = fract(world / tile_size);
COLOR      = texture(grass_tex, uv);
```

`player_pos` se actualiza cada frame con `player.global_position`.
La Camera2D no tiene `position_smoothing` — la cámara sigue al jugador 1:1,
que es el comportamiento estándar en horde survivors (Vampire Survivors incluido).
Con cámara 1:1, `player.global_position` siempre coincide con el centro del
viewport y el shader scroll queda en sync perfecto sin código extra.

---

## Capas de colisión

| Layer | Bit | Nombre     | Detecta       |
|-------|-----|------------|---------------|
| 1     | 1   | player     | walls (8)     |
| 2     | 2   | enemy      | —             |
| 3     | 4   | projectile | enemies (2)   |
| 4     | 8   | wall       | —             |

---

## Debug / desarrollo

- **F1** — spawn 200 enemigos en ring de 550u alrededor del jugador
- **ESC** — salir
- Todos los visuales son procedurales (`_draw()`), sin sprites externos salvo el tile de fondo
