use godot::prelude::*;
use std::collections::HashMap;

struct SimHotPathExtension;

#[gdextension]
unsafe impl ExtensionLibrary for SimHotPathExtension {}

/// Debe coincidir con PROJ_ZONE/PROJ_MISSILE de
/// game/sim/projectile_system.gd — duplicado como literal a propósito
/// (mismo criterio que tower_store.gd con los PROJ_* de GDScript, para no
/// crear una dependencia circular entre GDScript y Rust).
const PROJ_ZONE: i32 = 5;
const PROJ_MISSILE: i32 = 4;

/// Hot path de colisión (Sprint 2 Paso 4 / Fase 2, fase2-plan-proyectiles.md
/// Paso 3). Resuelve únicamente la búsqueda de colisión de los tipos que
/// "viajan" (recto/homing/perforante/splash) — el resto de la simulación
/// (movimiento, PROJ_ZONE, PROJ_MISSILE, stores, render sync) se queda en
/// GDScript. No muta ningún store: recibe posiciones ya actualizadas y
/// devuelve qué pegó con qué — GDScript decide qué hacer con eso (mismo
/// criterio que el contrato de Racimo que dejó anotado el director: la
/// llamada nativa reporta, no muta).
///
/// Contrato: arrays completos entre llamadas, una sola llamada por frame —
/// no por-entidad (ver la nota de marshaling en definicion-escala-v1.md).
#[derive(GodotClass)]
#[class(base=RefCounted)]
struct SimHotPath {
    base: Base<RefCounted>,
}

#[godot_api]
impl IRefCounted for SimHotPath {
    fn init(base: Base<RefCounted>) -> Self {
        Self { base }
    }
}

#[godot_api]
impl SimHotPath {
    /// Construye la grilla uniforme sobre enemy_positions[0..enemy_count] y,
    /// para cada proyectil "viajero" en proj_positions[0..proj_count] (se
    /// saltea PROJ_ZONE/PROJ_MISSILE — esos no pasan por acá, ver la nota de
    /// tick_native() en projectile_system.gd), busca el primer enemigo
    /// dentro de hit_radius en su celda + las 8 vecinas, excluyendo
    /// `proj_last_hit[p]` (perforante: no repegar al mismo enemigo en el
    /// frame siguiente — mismo problema que ya resolvió
    /// spatial_hash.gd::find_hit() en GDScript).
    ///
    /// Si `proj_splash_radius[p] > 0`, además busca los enemigos secundarios
    /// dentro de ese radio del punto de impacto (splash) y los reporta aparte.
    ///
    /// Devuelve un Dictionary con dos claves:
    /// - "primary": pares intercalados [proj_idx, enemy_idx, ...] — el
    ///   impacto principal de cada proyectil que pegó. GDScript decrementa
    ///   hits_remaining y decide muerte a partir de esto.
    /// - "splash": pares intercalados [proj_idx, enemy_idx, ...] — golpes
    ///   secundarios de splash, solo daño, sin bookkeeping de vida del
    ///   proyectil.
    #[func]
    fn find_collisions(
        &self,
        proj_positions: PackedVector2Array,
        proj_type_id: PackedInt32Array,
        proj_last_hit: PackedInt32Array,
        proj_splash_radius: PackedFloat32Array,
        proj_count: i32,
        enemy_positions: PackedVector2Array,
        enemy_count: i32,
        hit_radius: f32,
        cell_size: f32,
    ) -> Dictionary {
        let hit_radius_sq = hit_radius * hit_radius;
        let enemy_count = enemy_count as usize;
        let proj_count = proj_count as usize;

        let key_of = |p: Vector2| -> (i32, i32) {
            ((p.x / cell_size).floor() as i32, (p.y / cell_size).floor() as i32)
        };

        // Grilla: se reconstruye cada llamada, igual que spatial_hash.gd::build().
        let mut grid: HashMap<(i32, i32), Vec<i32>> = HashMap::with_capacity(enemy_count);
        for i in 0..enemy_count {
            let k = key_of(enemy_positions[i]);
            grid.entry(k).or_insert_with(Vec::new).push(i as i32);
        }

        let find_hit = |pos: Vector2, exclude: i32| -> i32 {
            let base = key_of(pos);
            for dx in -1..=1 {
                for dy in -1..=1 {
                    if let Some(bucket) = grid.get(&(base.0 + dx, base.1 + dy)) {
                        for &e_idx in bucket {
                            if e_idx == exclude {
                                continue;
                            }
                            let ep = enemy_positions[e_idx as usize];
                            if (ep - pos).length_squared() <= hit_radius_sq {
                                return e_idx;
                            }
                        }
                    }
                }
            }
            -1
        };

        let mut primary = PackedInt32Array::new();
        let mut splash = PackedInt32Array::new();

        for p in 0..proj_count {
            let t = proj_type_id[p];
            if t == PROJ_ZONE || t == PROJ_MISSILE {
                continue;
            }

            let pos = proj_positions[p];
            let hit_enemy = find_hit(pos, proj_last_hit[p]);
            if hit_enemy == -1 {
                continue;
            }

            primary.push(p as i32);
            primary.push(hit_enemy);

            let radius = proj_splash_radius[p];
            if radius > 0.0 {
                let radius_sq = radius * radius;
                let base = key_of(pos);
                for dx in -1..=1 {
                    for dy in -1..=1 {
                        if let Some(bucket) = grid.get(&(base.0 + dx, base.1 + dy)) {
                            for &e_idx in bucket {
                                if e_idx == hit_enemy {
                                    continue;
                                }
                                let ep = enemy_positions[e_idx as usize];
                                if (ep - pos).length_squared() <= radius_sq {
                                    splash.push(p as i32);
                                    splash.push(e_idx);
                                }
                            }
                        }
                    }
                }
            }
        }

        let mut result = Dictionary::new();
        result.set("primary", primary);
        result.set("splash", splash);
        result
    }
}
