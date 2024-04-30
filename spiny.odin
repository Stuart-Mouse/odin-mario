
package main

import sdl "vendor:sdl2"
import "core:fmt"

Spiny :: struct {
    using shell : Entity_Shell,

    walk_dir    : Direction,
    anim_clock  : int, 
}

update_spiny :: proc(spiny: ^Spiny) -> bool {
    using spiny
    position_prev = position

    anim_clock += 1
    if anim_clock >= GOOMBA_WALK_TIME do anim_clock = 0

    if walk_dir == .L {
        position.x -= GOOMBA_WALK_SPEED 
    } else if walk_dir == .R {
        position.x += GOOMBA_WALK_SPEED 
    }
    
    friction : f32 = .ON_GROUND in flags ? 0.9 : 1
    velocity.x *= friction

    velocity.y = min(Plumber_Physics.max_fall_speed, velocity.y + Plumber_Physics.fall_gravity) 
    position += velocity

    if .DEAD not_in base.flags {
        flags &= ~{.ON_GROUND}
        // do tilemap collision
        {
            tilemap := &GameState.active_level.tilemap
            size, offset := get_spiny_collision_size_and_offset(spiny^)
            using collision_result := do_tilemap_collision(tilemap, position, size, offset)
            position += position_adjust
            if .L in push_out {
                if walk_dir == .L do walk_dir = .R
            }
            if .R in push_out {
                if walk_dir == .R do walk_dir = .L
            }
            if .U in push_out {
                if velocity.y < 0 do velocity.y = Plumber_Physics.hit_ceiling
            }
            if .D in push_out {
                if velocity.y > 0 do velocity.y = 0
                flags |= {.ON_GROUND}
            }
            for dir in ([]Direction {.D, .DL, .DR}) {
                tile := get_tile(tilemap, indexed_tiles[dir])
                if tile != nil && tile_is_bumping(tile^) {
                    bump_dir := dir
                    if bump_dir == .D {
                        bump_dir = walk_dir
                    }
                    block_hit_entity(cast(^Entity)spiny, bump_dir)
                    break
                }
            }
        }

        // do collision with plumber
        {
            p          := &GameState.active_level.plumber
            p_inst_vel := p.position - p.position_prev
            p_rect     := get_plumber_collision_rect(p^)
            p_rect.x   -= p_inst_vel.x
            p_rect.y   -= p_inst_vel.y

            g_inst_vel := position - position_prev
            g_rect     := get_spiny_collision_rect(spiny^)
            g_rect.x   -= g_inst_vel.x
            g_rect.y   -= g_inst_vel.y
            
            collision, time, direction := swept_aabb_frect(p_rect, p_inst_vel, g_rect, g_inst_vel)
            if collision != 0 {
                plumber_take_damage(p)
            }
        }
    }

    if position.y > SCREEN_TILE_HEIGHT + 1 {
        return false
    }

    return true
}

spiny_animation_clips : [2] sdl.Rect = {
    { 48, 16, 16, 16 }, // walk 1
    { 64, 16, 16, 16 }, // walk 2
}

render_spiny :: proc(spiny: Spiny, tile_render_unit, offset: Vector2) {
    using GameState.active_level, spiny
    
    flip : sdl.RendererFlip
    clip, rect : sdl.Rect

    if .DEAD in spiny.base.flags {
        flip = .VERTICAL
        clip = spiny_animation_clips[0]
    } else {
        clip = spiny_animation_clips[int(anim_clock < GOOMBA_WALK_TIME / 2)]
        flip = walk_dir == .L ? .NONE : .HORIZONTAL
    }

    rect = {
        x = cast(i32) ((position.x - 0.5 + offset.x) * tile_render_unit.x),
        y = cast(i32) ((position.y - 0.5 + offset.y) * tile_render_unit.y),
        w = cast(i32) (tile_render_unit.x), 
        h = cast(i32) (tile_render_unit.y),
    }

    sdl.RenderCopyEx(renderer, entities_texture.sdl_texture, &clip, &rect, 0, nil, flip)
}

get_spiny_collision_rect :: proc(spiny: Spiny) -> sdl.FRect {
    using spiny
    size, offset := get_spiny_collision_size_and_offset(spiny)
    return {
        x = position.x + offset.x,
        y = position.y + offset.y,
        w = size.x,
        h = size.y,
    }    
}

get_spiny_collision_size_and_offset :: proc(using spiny: Spiny) -> (size, offset :Vector2) {
    size     = scale * Vector2 { 14.0 / 16.0, 11.0 / 16.0 }
    offset = -(size / 2) + {0, (1.0 / 16.0)}
    return
}

