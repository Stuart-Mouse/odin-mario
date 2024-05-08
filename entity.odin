package main

import sdl "vendor:sdl2"
import "core:fmt"

entities_texture : Texture

Entity_Base :: struct {
    entity_type   : Entity_Type, 
    entity_flags  : Entity_Flags, 
    
    position_prev : Vector2, 
    position      : Vector2, 
    velocity      : Vector2, 
}

Entity_Flags :: bit_set[Entity_Flag]
Entity_Flag  :: enum {
    REMOVE_ME,
}

Entity_Type :: enum {
    NONE,
    ENEMY,
    ITEM,
    PROJECTILE,
}

Entity :: struct #raw_union {
    base       : Entity_Base,
    enemy      : Enemy,
    item       : Item,
    projectile : Projectile,
}

// this is silly, maybe we remove this proc, or we could call into the init routines for individual entity types with some default args?
init_entity :: proc(entity: ^Entity, type: Entity_Type) {
    if entity == nil do return 
    entity.base = {
        entity_type  = type,
    }
}

update_entity :: proc(using entity: ^Entity) {
    if entity == nil do return
    #partial switch base.entity_type {
        case .ENEMY      : update_enemy     (&enemy     )
        case .ITEM       : update_item      (&item      )
        case .PROJECTILE : update_projectile(&projectile)
    }
}

render_entity :: proc(using entity: ^Entity, render_unit: f32, offset: Vector2, alpha_mod: f32 = 1) {
    #partial switch base.entity_type {
        case .ENEMY     : render_enemy      (&enemy      , render_unit, offset, alpha_mod)
        case .ITEM      : render_item       (&item       , render_unit, offset, alpha_mod)
        case .PROJECTILE: render_projectile (&projectile , render_unit, offset, alpha_mod)
    }
}

get_entity_collision_rect :: proc(using entity: Entity) -> sdl.FRect {
    #partial switch base.entity_type {
        case .ENEMY      : return get_enemy_collision_rect     (enemy     )
        case .ITEM       : return get_item_collision_rect      (item      )
        case .PROJECTILE : return get_projectile_collision_rect(projectile)
    }
    return {}
}

frect_from_position_size_offset :: proc(position, size, offset: Vector2) -> sdl.FRect {
    return sdl.FRect {
        x = position.x + offset.x,
        y = position.y + offset.y,
        w = size.x,
        h = size.y,
    }
}

rect_from_position_size_offset :: proc(position, size, offset: Vector2) -> sdl.Rect {
    return sdl.Rect {
        x = i32(position.x + offset.x),
        y = i32(position.y + offset.y),
        w = i32(size.x),
        h = i32(size.y),
    }
}

shell_hit_entity :: proc(using entity: ^Entity) -> bool {
    #partial switch base.entity_type {
        case .ENEMY: return shell_hit_enemy(&enemy)
        case .ITEM : return shell_hit_item (&item )
    }
    return false
}

fireball_hit_entity :: proc(using entity: ^Entity) -> bool {
    #partial switch base.entity_type {
        case .ENEMY: return fireball_hit_enemy(&enemy)
        case .PROJECTILE: return true
    }
    return false
}
