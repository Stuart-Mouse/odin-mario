package main

import sdl "vendor:sdl2"
import "core:fmt"

entities_texture : Texture

Entity_Base :: struct {
    tag           : Entity_Type, 
    position_prev : Vector2, 
    position      : Vector2, 
    velocity      : Vector2, 
    scale         : Vector2, 
    flags         : Entity_Flags, 
}

Entity_Flags :: bit_set[Entity_Flag]
Entity_Flag  :: enum {
    ON_GROUND,
    DEAD,
    CRUSHED,    // only applies to goomba

    MOVING,     // only applies to shells
    FLIPPED,    // only applies to shells
    
    // Behavioral flags
    DONT_WALK_OFF_LEDGES,
    IMMUNE_TO_FIRE,
    SPIKED,
    WINGED,
}

Entity_Type :: enum {
    NONE,
    GOOMBA,
    MUSHROOM,
    SHELL,
    BEETLE,
    KOOPA,
    FIREBALL,
    SPINY,
    COIN,
}

Entity :: struct #raw_union {
    base     : Entity_Base,
    goomba   : Goomba,
    mushroom : Mushroom,
    shell    : Entity_Shell,
    beetle   : Beetle,
    koopa    : Koopa,
    fireball : Fireball,
    spiny    : Spiny,
    coin     : Coin,
}

init_entity :: proc(entity: ^Entity, type: Entity_Type, flags: Entity_Flags = {}, hint_dir: Direction = .L) {
    if entity == nil do return 
    
    entity.base = {
        tag   = type,
        flags = flags,
        scale = { 1, 1 },
    }

    #partial switch type {
        case .GOOMBA:
            using entity.goomba
            walk_dir = hint_dir
          
        case .MUSHROOM:
            using entity.mushroom
            if GameState.active_level.plumber.powerup >= .SUPER {
                powerup = .FIRE
            } else {
                powerup  = .SUPER
                walk_dir = hint_dir
            }
          
        case .SHELL:
            using entity.shell
            shell_clip = koopa_animation_clips[2]
          
        case .BEETLE:
            using entity.beetle
            walk_dir   = hint_dir
            shell_clip = beetle_animation_clips[2]
            flags |= {.IMMUNE_TO_FIRE}
          
        case .KOOPA:
            using entity.koopa
            walk_dir   = hint_dir
            shell_clip = koopa_animation_clips[2]
            if .DONT_WALK_OFF_LEDGES in flags {
                shell_clip.y += 24
            }
          
        case .SPINY:
            using entity.spiny
            walk_dir   = hint_dir
          
        case .FIREBALL:
        
        case .COIN:
            
          
        case:
            assert(false)
    }
    entity.base.tag = type
}

render_entity :: proc(using entity: Entity, tile_render_unit, offset: Vector2) {
    clip, rect : sdl.Rect
    flip : sdl.RendererFlip

    #partial switch base.tag {
        case .GOOMBA   : render_goomba  (goomba  , tile_render_unit, offset)
        case .MUSHROOM : render_mushroom(mushroom, tile_render_unit, offset)
        case .SHELL    : render_shell   (shell   , tile_render_unit, offset)
        case .BEETLE   : render_beetle  (beetle  , tile_render_unit, offset)
        case .KOOPA    : render_koopa   (koopa   , tile_render_unit, offset)
        case .FIREBALL : render_fireball(fireball, tile_render_unit, offset)
        case .SPINY    : render_spiny   (spiny   , tile_render_unit, offset)
        case .COIN     : render_coin    (coin    , tile_render_unit, offset)
    }
}

update_entity :: proc(using entity: ^Entity) -> bool {
    if entity == nil do return true

    if entity.base.position.x < GameState.active_level.camera.position.x - SCREEN_TILE_WIDTH / 2 ||
       entity.base.position.x > GameState.active_level.camera.position.x + SCREEN_TILE_WIDTH + 2 {
        return true
    }

    #partial switch base.tag {
        case .GOOMBA   : update_goomba  (&goomba  ) or_return
        case .MUSHROOM : update_mushroom(&mushroom) or_return
        case .SHELL    : update_shell   (&shell   ) or_return
        case .BEETLE   : update_beetle  (&beetle  ) or_return
        case .KOOPA    : update_koopa   (&koopa   ) or_return
        case .FIREBALL : update_fireball(&fireball) or_return
        case .SPINY    : update_spiny   (&spiny   ) or_return
        case .COIN     : update_coin    (&coin    ) or_return
    }

    return true
}

get_entity_collision_rect :: proc(using entity: Entity) -> sdl.FRect {
    #partial switch base.tag {
        case .GOOMBA   : return get_goomba_collision_rect  (goomba  )
        case .MUSHROOM : return get_mushroom_collision_rect(mushroom)
        case .SHELL    : return get_shell_collision_rect   (shell   )
        case .BEETLE   : return get_beetle_collision_rect  (beetle  )
        case .KOOPA    : return get_koopa_collision_rect   (koopa   )
        case .FIREBALL : return get_fireball_collision_rect(fireball)
        case .SPINY    : return get_spiny_collision_rect   (spiny   )
        case .COIN     : return get_coin_collision_rect    (coin    )
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
    #partial switch entity.base.tag {
        case .MUSHROOM, .COIN: 
            base.velocity.y -= 0.25

        case .GOOMBA, .SPINY:
            if .DEAD not_in base.flags {
                base.flags |= {.DEAD}
                base.velocity.y -= 0.25
                return true
            }

        case .BEETLE, .KOOPA, .SHELL:
            if .DEAD not_in base.flags {
                base.flags |= {.FLIPPED}
                base.flags |= {.DEAD}
                base.velocity.y -= 0.25
                return true
            }
    }
    
    return false
}

fireball_hit_entity :: proc(using entity: ^Entity) -> bool {
    if .IMMUNE_TO_FIRE in base.flags do return false
    if .DEAD           in base.flags do return false
  
    GameState.active_level.plumber.score += 100
    spawn_score_particle(0, base.position)
  
    #partial switch entity.base.tag {
        case .GOOMBA, .SPINY:
            base.velocity.y -= 0.25
            base.flags |= {.DEAD}
  
        case .BEETLE, .KOOPA, .SHELL:
            shell.shell_clock = 1
            base.flags |= {.FLIPPED}
            base.flags |= {.DEAD}
            base.velocity.y -= 0.25
    }
    
    return true
}

block_hit_entity :: proc(using entity: ^Entity, bump_dir: Direction = .U) {
    if .DEAD in base.flags do return

    bump_vel := Vector2 { 0, 0.25 }
    if bump_dir == .L { // these are sorta flipped bc of how we get the sides in entity code. should change this probably
        bump_vel.x = 0.05
    } else if bump_dir == .R {
        bump_vel.x = -0.05
    }

    #partial switch entity.base.tag {
        case .MUSHROOM, .COIN: 
            base.velocity -= bump_vel

        case .GOOMBA, .SPINY:
            base.velocity -= bump_vel
            base.flags |= {.DEAD}

        case .BEETLE, .KOOPA:
            base.flags &= ~{.WINGED}
            shell.shell_clock = 60 * 5
            fallthrough

        case .SHELL:
            base.flags ~= {.FLIPPED}
            base.velocity -= bump_vel
    }
}
