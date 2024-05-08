package main

import sdl "vendor:sdl2"
import "core:fmt"
import "core:math"

Projectile :: struct  {
    using base : Entity_Base,
    
    acceleration  : Vector2,
    friction      : Vector2,
    vel_min       : Vector2,
    vel_max       : Vector2,
     
    type     : Projectile_Type,
    flags    : Projectile_Flags,
    animator : Projectile_Animator,
}

Projectile_Flags :: bit_set[Projectile_Flag]
Projectile_Flag  :: enum {
    COLLIDE_TILEMAP,
    COLLIDE_PLAYER,
    COLLIDE_ENTITIES,
    
    BOUNCE_ON_FLOOR,
    BOUNCE_ON_WALLS,
    
    DIE_ON_FLOOR,
    DIE_ON_WALLS,
    
    DIE_ON_COLLIDE,
}

Projectile_Animator :: Simple_Animator(Projectile_Animation_State)

projectile_animations: [Projectile_Type] [Projectile_Animation_State] Simple_Animation

Projectile_Type :: enum {
    FIREBALL,
    HAMMER,
    BOWSER_FIRE,
    SPIKE_BALL,
}

Projectile_Animation_State :: enum {
    ALIVE,
    DEAD,
}

init_projectile_animations :: proc() {
    projectile_animations[.FIREBALL][.ALIVE].flags |= { .LOOP }
    append(&projectile_animations[.FIREBALL][.ALIVE].frames, Simple_Animation_Frame {
        offset   = { -0.25, -0.25 },
        clip     = { 48, 0, 8, 8 },
        duration = 5,
    })
    append(&projectile_animations[.FIREBALL][.ALIVE].frames, Simple_Animation_Frame {
        offset   = { -0.25, -0.25 },
        clip     = { 56, 0, 8, 8 },
        duration = 5,
    })
    append(&projectile_animations[.FIREBALL][.ALIVE].frames, Simple_Animation_Frame {
        offset   = { -0.25, -0.25 },
        clip     = { 48, 0, 8, 8 },
        duration = 5,
    })
    append(&projectile_animations[.FIREBALL][.ALIVE].frames, Simple_Animation_Frame {
        offset   = { -0.25, -0.25 },
        clip     = { 56, 0, 8, 8 },
        duration = 5,
    })
    
    append(&projectile_animations[.FIREBALL][.DEAD].frames, Simple_Animation_Frame {
        offset   = { -0.5, -0.5 },
        clip     = { 64, 0, 16, 16 },
        duration = 3,
    })
    append(&projectile_animations[.FIREBALL][.DEAD].frames, Simple_Animation_Frame {
        offset   = { -0.5, -0.5 },
        clip     = { 80, 0, 16, 16 },
        duration = 3,
    })
    append(&projectile_animations[.FIREBALL][.DEAD].frames, Simple_Animation_Frame {
        offset   = { -0.5, -0.5 },
        clip     = { 96, 0, 16, 16 },
        duration = 3,
    })
    
    
    projectile_animations[.HAMMER][.ALIVE].flags |= { .LOOP }
    append(&projectile_animations[.HAMMER][.ALIVE].frames, Simple_Animation_Frame {
        offset   = { -0.25, -0.5 },
        clip     = { 32, 16, 8, 16 },
        duration = 5,
    })
    append(&projectile_animations[.HAMMER][.ALIVE].frames, Simple_Animation_Frame {
        offset   = { -0.5, -0.25 },
        clip     = { 40, 24, 16, 8 },
        duration = 5,
    })
    append(&projectile_animations[.HAMMER][.ALIVE].frames, Simple_Animation_Frame {
        offset   = { -0.25, -0.5 },
        clip     = { 56, 16, 8, 16 },
        duration = 5,
    })
    append(&projectile_animations[.HAMMER][.ALIVE].frames, Simple_Animation_Frame {
        offset   = { -0.5, -0.25 },
        clip     = { 40, 16, 16, 8 },
        duration = 5,
    })
    projectile_animations[.HAMMER][.DEAD] = projectile_animations[.HAMMER][.ALIVE]
    
    
    projectile_animations[.SPIKE_BALL][.ALIVE].flags |= { .LOOP }
    append(&projectile_animations[.SPIKE_BALL][.ALIVE].frames, Simple_Animation_Frame {
        offset   = { -0.5, -0.5 },
        clip     = { 64, 16, 16, 16 },
        duration = 5,
    })
    append(&projectile_animations[.SPIKE_BALL][.ALIVE].frames, Simple_Animation_Frame {
        offset   = { -0.5, -0.5 },
        clip     = { 64, 16, 16, 16 },
        duration = 5,
        flip     = .VERTICAL
    })
    projectile_animations[.SPIKE_BALL][.DEAD] = projectile_animations[.SPIKE_BALL][.ALIVE]

}

init_projectile :: proc(projectile: ^Projectile, type: Projectile_Type) {
    projectile.entity_type = .PROJECTILE
    projectile.type = type
    set_animation(&projectile.animator, Projectile_Animation_State.ALIVE)
}

update_projectile :: proc(using projectile: ^Projectile) {
    // remove projectiles that go off screen
    if position.x < GameState.active_level.camera.position.x - 2 ||
       position.x > GameState.active_level.camera.position.x + SCREEN_TILE_WIDTH + 2 ||
       position.y < -2 || position.y > SCREEN_TILE_HEIGHT + 2 {
        entity_flags |= { .REMOVE_ME }
        return 
    }
    
    // using the animator state here to control gameplay code is not ideal, just a quick fix
    if animator.state == .DEAD {
        if .STOPPED in animator.flags {
            entity_flags |= { .REMOVE_ME }
        }
        return
    }

    position_prev = position // TODO: we should probably remove prev_position from base entity....
    
    velocity += acceleration
    velocity.x = clamp(velocity.x, vel_min.x, vel_max.x)
    velocity.y = clamp(velocity.y, vel_min.y, vel_max.y)
    
    position += velocity

    // collide tilemap
    if .COLLIDE_TILEMAP in flags {
        tilemap := &GameState.active_level.tilemap
        size, offset := get_projectile_collision_size_and_offset(projectile^)
        using collision_result := do_tilemap_collision(tilemap, position, size, offset)
        position += position_adjust
        if .L in push_out {
            if .DIE_ON_WALLS in flags {
                set_animation(&animator, Projectile_Animation_State.DEAD)
            } else if velocity.x < 0 {
                if .BOUNCE_ON_WALLS in flags {
                    velocity.x *= -1.05
                } else {
                    velocity.x = 0
                }
            }
        }
        if .R in push_out {
            if .DIE_ON_WALLS in flags {
                set_animation(&animator, Projectile_Animation_State.DEAD)
            } else if velocity.x > 0 {
                if .BOUNCE_ON_WALLS in flags {
                    velocity.x *= -1.05
                } else {
                    velocity.x = 0
                }
            }
        }
        if .U in push_out {
            if .DIE_ON_WALLS in flags {
                set_animation(&animator, Projectile_Animation_State.DEAD)
            } else if velocity.y < 0 {
                if .BOUNCE_ON_WALLS in flags {
                    velocity.y *= -1.05
                } else {
                    velocity.y = 0
                }
            }
        }
        if .D in push_out {
            if .DIE_ON_FLOOR in flags {
                set_animation(&animator, Projectile_Animation_State.DEAD)
            } else if velocity.y > 0 {
                if .BOUNCE_ON_FLOOR in flags {
                    velocity.y *= -1.05
                } else {
                    velocity.y = 0
                }
            }
        }
    }
    
    // collision with other entities (do this in its own update loop? maybe later)
    if .COLLIDE_ENTITIES in flags {
        for &slot, i in GameState.active_level.entities.slots {
            if slot.occupied {
                other := &slot.data
                if uintptr(projectile) == uintptr(other) do continue
                projectile_rect := get_projectile_collision_rect(projectile^)
                other_rect := get_entity_collision_rect(other^)
                if aabb_frect(projectile_rect, other_rect) {
                    if fireball_hit_entity(other) {
                        if .DIE_ON_COLLIDE in flags {
                            set_animation(&animator, Projectile_Animation_State.DEAD)
                            return 
                        }
                    }
                }
            }
        }
    }
    
    if .COLLIDE_PLAYER in flags {
        plumber := &GameState.active_level.plumber
        p_rect := get_plumber_collision_rect(plumber^)
        e_rect := get_projectile_collision_rect(projectile^)
        
        if aabb_frect(p_rect, e_rect) {
            plumber_take_damage(plumber)
            if .DIE_ON_COLLIDE in flags {
                set_animation(&animator, Projectile_Animation_State.DEAD)
                return 
            }
        }
    }
}

render_projectile :: proc(using projectile: ^Projectile, render_unit: f32, offset: Vector2, alpha_mod: f32 = 1) {
    step_animator(&animator, &projectile_animations[type])

    current_animation := &projectile_animations[type][animator.state]
    current_frame     := &current_animation.frames[animator.current_frame]
    
    flip := current_frame.flip
    clip := current_frame.clip
    rect := sdl.Rect {
        x = i32((position.x + current_frame.offset.x + offset.x) * render_unit),
        y = i32((position.y + current_frame.offset.y + offset.y) * render_unit),
        w = i32((cast(f32) clip.w) / 16.0 * render_unit),
        h = i32((cast(f32) clip.h) / 16.0 * render_unit),
    }
    
    sdl.SetTextureAlphaMod(entities_texture.sdl_texture, u8(alpha_mod * 255))
    sdl.RenderCopyEx(renderer, entities_texture.sdl_texture, &clip, &rect, 0, nil, flip)
    sdl.SetTextureAlphaMod(entities_texture.sdl_texture, 0xFF)
}

get_projectile_collision_size_and_offset :: proc(using projectile: Projectile) -> (size, offset: Vector2) {
    switch type {
        case .FIREBALL:
            return { 0.5, 0.5 }, { -0.25, -0.25 }
        case .HAMMER:
            return { 0.5, 0.5 }, { -0.25, -0.25 }
        case .SPIKE_BALL:
            return { 1.0, 1.0 }, { -0.5, -0.5 }
        case .BOWSER_FIRE:
    }
    return {}, {}
}

get_projectile_collision_rect :: proc(using projectile: Projectile) -> sdl.FRect {
    size, offset := get_projectile_collision_size_and_offset(projectile)
    return {
        x = position.x + offset.x,
        y = position.y + offset.y,
        w = size.x,
        h = size.y,
    }
}