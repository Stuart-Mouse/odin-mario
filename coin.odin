package main

import sdl "vendor:sdl2"
import "core:fmt"

Coin :: struct {
    using base : Entity_Base,
    walk_dir   : Direction,
    animation : struct {
        frame_counter : int,
        frame_index   : int,
    }
}

coin_animation_clips: [] struct { clip: sdl.Rect, duration: int } = {
    { { 112, 0, 8, 16 }, 5 },
    { { 120, 0, 8, 16 }, 5 },
    { { 128, 0, 8, 16 }, 5 },
    { { 136, 0, 8, 16 }, 5 },
}

render_coin :: proc(coin: Coin, tile_render_unit, offset: Vector2) {
    using GameState.active_level, coin, coin.animation
    
    flip : sdl.RendererFlip
    clip, rect : sdl.Rect
    
    frame_counter += 1
    if frame_counter >= coin_animation_clips[frame_index].duration {
        frame_index += 1
        frame_counter = 0
        if frame_index >= len(coin_animation_clips) {
            frame_index = 0
        }
    }
    
    clip = coin_animation_clips[frame_index].clip

    rect = {
        x = cast(i32) ((position.x - 0.25 + offset.x) * tile_render_unit.x),
        y = cast(i32) ((position.y - 0.5  + offset.y) * tile_render_unit.y),
        w = cast(i32) (tile_render_unit.x / 2), 
        h = cast(i32) (tile_render_unit.y    ),
    }

    sdl.RenderCopyEx(renderer, entities_texture.sdl_texture, &clip, &rect, 0, nil, flip)
}

update_coin :: proc(coin: ^Coin) -> bool {
    using coin
    position_prev = position

    // apply gravity to the coin
    velocity.y = min(Plumber_Physics.max_fall_speed, velocity.y + Plumber_Physics.fall_gravity) 

    friction : f32 = .ON_GROUND in flags ? 0.99 : 1
    velocity.x *= friction

    // apply the velocity to the position
    position += velocity

    // if the coin is dead, it will not collide with anything anymore, but we will wait for it to fall off the screen before actually destroying it
    if .DEAD not_in flags {
        flags &= ~{.ON_GROUND}
    
        // do tilemap collision
        {
            tilemap := &GameState.active_level.tilemap
            size, offset := get_coin_collision_size_and_offset(coin^)
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
                if velocity.y > 0 do velocity.y *= -0.5
                flags |= {.ON_GROUND}
            }
            for dir in ([]Direction {.D, .DL, .DR}) {
                tile := get_tile(tilemap, indexed_tiles[dir])
                if tile != nil && tile_is_bumping(tile^) {
                    bump_dir := dir
                    if bump_dir == .D {
                        bump_dir = walk_dir
                    }
                    block_hit_entity(cast(^Entity)coin, bump_dir)
                    break
                }
            }
        }

        // do collision with plumber
        {
            p          := &GameState.active_level.plumber
            p_inst_vel := p.position - p.position_prev
            p_rect     := get_plumber_collision_rect(p^)

            g_inst_vel := position - position_prev
            g_rect     := get_coin_collision_rect(coin^)
            
            if aabb_frect(p_rect, g_rect) {
                p.coins += 1
                p.score += 200
                spawn_score_particle(1, position)
                return false
            }
        }
    }

    // check if the coin has fallen out of the level
    if position.y > SCREEN_TILE_HEIGHT + 1 {
        return false
    }

    return true
}

get_coin_collision_rect :: proc(coin: Coin) -> sdl.FRect {
    using coin
    size, offset := get_coin_collision_size_and_offset(coin)
    return {
        x = position.x + offset.x,
        y = position.y + offset.y,
        w = size.x,
        h = size.y,
    }    
}

get_coin_collision_size_and_offset :: proc(using coin: Coin) -> (size, offset :Vector2) {
    size   = scale * Vector2 { 14.0 / 16.0, 11.0 / 16.0 }
    offset = -(size / 2) + {0, (1.0 / 16.0)}
    return
}

spawn_coin_particle :: proc(spawn_position: Vector2) {   
    frames_each   := 5
    loop          := 2 // one more than actual, need to not divide by zero below
    velocity      : Vector2 = { 0, -0.3 }
    acceleration  : Vector2 = (2.0 * -velocity) / (f32(loop) * 4.0 * f32(frames_each))
 
    using GameState.active_level
    slot := get_next_slot(&particles[0])
    slot.occupied = true
    slot.data = {
        velocity     = velocity,
        acceleration = acceleration,
        position  = spawn_position,
        scale     = { 1, 1 },
        texture   = entities_texture.sdl_texture,
        animation = {
            loop = loop-1,
            frame_count = 4,
            frames = {
                { { 112, 0, 8, 16 }, frames_each },
                { { 120, 0, 8, 16 }, frames_each },
                { { 128, 0, 8, 16 }, frames_each },
                { { 136, 0, 8, 16 }, frames_each },
                {}, {}, {}, {},
            },
        },
    }
}