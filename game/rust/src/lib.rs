use godot::prelude::*;
use std::collections::HashMap;

struct SimHotPathExtension;

#[gdextension]
unsafe impl ExtensionLibrary for SimHotPathExtension {}

/// Hot path de colisión (Sprint 2, Paso 4 — Ruta B). Reemplaza únicamente la
/// consulta al hash espacial de projectile_system.gd/spatial_hash.gd — el
/// resto de la simulación (movimiento, stores, render sync) se queda en
/// GDScript, según el corte de directorsuggestions.md.
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
    /// para cada proyectil en proj_positions[0..proj_count], busca el primer
    /// enemigo dentro de hit_radius en su celda + las 8 vecinas (mismo
    /// algoritmo que spatial_hash.gd + projectile_system.gd::_check_collision,
    /// en código nativo).
    ///
    /// Devuelve un array plano de pares intercalados [proj_idx, enemy_idx, ...]
    /// — GDScript se queda con la aplicación de daño y el swap-remove, que ya
    /// tiene que tocar los stores igual.
    #[func]
    fn find_collisions(
        &self,
        proj_positions: PackedVector2Array,
        proj_count: i32,
        enemy_positions: PackedVector2Array,
        enemy_count: i32,
        hit_radius: f32,
        cell_size: f32,
    ) -> PackedInt32Array {
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

        let mut out = PackedInt32Array::new();
        for p in 0..proj_count {
            let pos = proj_positions[p];
            let base = key_of(pos);
            let mut hit_enemy: i32 = -1;

            'search: for dx in -1..=1 {
                for dy in -1..=1 {
                    if let Some(bucket) = grid.get(&(base.0 + dx, base.1 + dy)) {
                        for &e_idx in bucket {
                            let ep = enemy_positions[e_idx as usize];
                            let dist_sq = (ep - pos).length_squared();
                            if dist_sq <= hit_radius_sq {
                                hit_enemy = e_idx;
                                break 'search;
                            }
                        }
                    }
                }
            }

            if hit_enemy != -1 {
                out.push(p as i32);
                out.push(hit_enemy);
            }
        }

        out
    }
}
