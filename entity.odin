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
    // GOOMBA,
    // MUSHROOM,
    // SHELL,
    // BEETLE,
    // KOOPA,
    // FIREBALL,
    // SPINY,
    // COIN,
}

Entity :: struct #raw_union {
    base     : Entity_Base,
    enemy    : Enemy,
    item     : Item,
    // goomba   : Goomba,
    // mushroom : Mushroom,
    // shell    : Entity_Shell,
    // beetle   : Beetle,
    // koopa    : Koopa,
    // fireball : Fireball,
    // spiny    : Spiny,
    // coin     : Coin,
}

init_entity :: proc(entity: ^Entity, type: Entity_Type) {
    if entity == nil do return 
    entity.base = {
        entity_type  = type,
    }
}

update_entity :: proc(using entity: ^Entity) -> bool {
    if entity == nil do return true

    if entity.base.position.x < GameState.active_level.camera.position.x - SCREEN_TILE_WIDTH / 2 ||
       entity.base.position.x > GameState.active_level.camera.position.x + SCREEN_TILE_WIDTH + 2 {
        return true
    }

    #partial switch base.entity_type {
        case .ENEMY: update_enemy(&enemy) or_return
        case .ITEM : update_item (&item ) or_return
    }

    return true
}

render_entity :: proc(using entity: ^Entity, render_unit: f32, offset: Vector2, alpha_mod: f32 = 1) {
    #partial switch base.entity_type {
        case .ENEMY: render_enemy(&enemy, render_unit, offset, alpha_mod)
        case .ITEM : render_item (&item , render_unit, offset, alpha_mod)
    }
}

get_entity_collision_rect :: proc(using entity: Entity) -> sdl.FRect {
    #partial switch base.entity_type {
        case .ENEMY: return get_enemy_collision_rect(enemy)
        case .ITEM : return get_item_collision_rect (item )
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
    }
    return false
}

fireball_hit_entity :: proc(using entity: ^Entity) -> bool {
    #partial switch base.entity_type {
        case .ENEMY: return fireball_hit_enemy(&enemy)
    }
    return true
}

// block_hit_entity :: proc(using entity: ^Entity, bump_dir: Direction = .U) {
//     bump_vel := Vector2 { 0, 0.25 }
//     if bump_dir == .L { // these are sorta flipped bc of how we get the sides in entity code. should change this probably
//         bump_vel.x = 0.05
//     } else if bump_dir == .R {
//         bump_vel.x = -0.05
//     }

//     #partial switch entity.base.tag {
//         case .MUSHROOM, .COIN: 
//             base.velocity -= bump_vel

//         case .GOOMBA, .SPINY:
//             base.velocity -= bump_vel
//             base.flags |= {.DEAD}

//         case .BEETLE, .KOOPA:
//             base.flags &= ~{.WINGED}
//             shell.shell_clock = 60 * 5
//             fallthrough

//         case .SHELL:
//             base.flags ~= {.FLIPPED}
//             base.velocity -= bump_vel
//     }
// }
