package main

import sdl "vendor:sdl2"
import "core:fmt"

Fireball :: struct {
  using base : Entity_Base,
  anim_clock : int, 
}

fireball_animation_clips : [7] sdl.Rect = {
    // fireball rotation anim
    {  48,  0,  8,  8 },
    {  56,  0,  8,  8 },
    {  48,  8,  8,  8 },
    {  56,  8,  8,  8 },
    
    // fireball death anim
    {  64,  0, 16, 16 },
    {  80,  0, 16, 16 },
    {  96,  0, 16, 16 },
}

FIREBALL_ANIM_TIME  :: 12 // 12 is evenly divisible by both 4 and 3, which makes it ideal for both our anim lengths
FIREBALL_BOUNCE_FORCE : f32 = 0.2

render_fireball :: proc(fireball: Fireball, tile_render_unit, offset: Vector2) {
    using GameState.active_level, fireball
    
    flip : sdl.RendererFlip
    clip, rect : sdl.Rect
    
    if .DEAD in flags {
        clip_i := 4+(anim_clock*3/FIREBALL_ANIM_TIME)
        clip = fireball_animation_clips[clip_i]
    } else {
        clip_i := anim_clock*4/FIREBALL_ANIM_TIME
        clip = fireball_animation_clips[clip_i]
    }
  
    render_scale := Vector2 {
        f32(clip.w) / 16,
        f32(clip.h) / 16,
    }
    
    rect = {
        x = cast(i32) ((position.x - render_scale.x/2 + offset.x) * tile_render_unit.x),
        y = cast(i32) ((position.y - render_scale.y/2 + offset.y) * tile_render_unit.y),
        w = cast(i32) (render_scale.x * tile_render_unit.x), 
        h = cast(i32) (render_scale.y * tile_render_unit.y),
    }
  
    sdl.RenderCopyEx(renderer, entities_texture.sdl_texture, &clip, &rect, 0, nil, flip)
}

update_fireball :: proc(fireball: ^Fireball) -> bool {
    using fireball
    position_prev = position
  
    anim_clock += 1
    if anim_clock >= FIREBALL_ANIM_TIME {
        anim_clock = 0
        if .DEAD in flags do return false
    } 
  
    if .DEAD not_in flags {
        velocity.y = min(Plumber_Physics.max_fall_speed * 0.75, velocity.y + Plumber_Physics.fall_gravity) 
        position += velocity
    
        // do tilemap collision
        {
            size, offset := get_fireball_collision_size_and_offset(fireball^)
            using collision_result := do_tilemap_collision(&GameState.active_level.tilemap, position, size, offset)
            position += position_adjust
            if .D in push_out {
                velocity.y = -FIREBALL_BOUNCE_FORCE
            }
            if .L in push_out {
                flags |= {.DEAD}
            }
            if .R in push_out {
                flags |= {.DEAD}
            }
            if .U in push_out {
                flags |= {.DEAD}
            }
        }
    
        // do collision with entities
        for &slot in GameState.active_level.entities.slots {
            if slot.occupied && slot.data.base.tag != .FIREBALL {
                s_rect := get_fireball_collision_rect(fireball^)
                e_rect := get_entity_collision_rect(slot.data)
                if aabb_frect(s_rect, e_rect) {
                    if fireball_hit_entity(&slot.data) {
                        flags |= {.DEAD}
                    }
                }
            }
        }
    }
  
    // check if the goomba has fallen out of the level
    if position.y > SCREEN_TILE_HEIGHT + 1 ||
       position.x < GameState.active_level.camera.position.x - 1 ||
       position.x > GameState.active_level.camera.position.x + SCREEN_TILE_WIDTH + 1 {
        return false
    }
  
    return true
}

get_fireball_collision_rect :: proc(using fireball: Fireball) -> sdl.FRect {
    size, offset := get_fireball_collision_size_and_offset(fireball)
    return {
        x = position.x + offset.x,
        y = position.y + offset.y,
        w = size.x,
        h = size.y,
    }  
}

get_fireball_collision_size_and_offset :: proc(using fireball: Fireball) -> (size, offset: Vector2) {
    size   = scale * Vector2 { 8.0 / 16.0, 8.0 / 16.0 }
    offset = -(size / 2)
    return
}
