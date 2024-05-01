package main

import sdl "vendor:sdl2"
import "core:fmt"

show_enemy_collision_rects := true

enemy_templates: [dynamic] Enemy_Template

find_enemy_template_by_name :: proc(name: string) -> ^Enemy_Template {
    for &et in enemy_templates {
        if et.name == name do return &et
    }
    return nil
}

find_enemy_template_by_uuid :: proc(uuid: u64) -> ^Enemy_Template {
    for &et in enemy_templates {
        if et.uuid == uuid do return &et
    }
    return nil
}

init_enemy_templates :: proc() {
    {
        using template: Enemy_Template
        
        name = "Goomba"
        uuid = 0xdc797d23457d924a
        
        movement_style = .GOOMBA
        movement_speed = 0.025
        
        collision_size   = { 14.0 / 16.0, 12.0 / 16.0 }
        collision_offset = -(collision_size / 2) + {0, (1.0 / 16.0)}
        
        animations[.WALK].flags |= { .LOOP }
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 0, 0, 16, 16 },
            duration = 20,
        })
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 0, 0, 16, 16 },
            flip     = .HORIZONTAL,
            duration = 20,
        })
        append(&animations[.CRUSHED].frames, Simple_Animation_Frame {
            offset = { -0.5, -0.5 },
            clip   = { 0, 0, 16, 16 },
        })
        append(&animations[.DEAD].frames, Simple_Animation_Frame {
            offset = { -0.5, -0.5 },
            clip   = { 16, 0, 16, 16 },
            flip   = .VERTICAL,
        })
        
        append(&enemy_templates, template)
    }
}

Enemy :: struct  {
    template      : ^Enemy_Template, // readonly at level runtime!
    flags         : Enemy_Flags,
    animator      : Enemy_Animator,
    
    position_prev : Vector2,
    position      : Vector2,
    velocity      : Vector2,
    
    walk_dir      : Direction,
}

Enemy_Flags :: bit_set[Enemy_Flag]
Enemy_Flag  :: enum {
    // general states
    ON_GROUND,
    DEAD,
    CRUSHED,

    // shell flags
    MOVING,
    FLIPPED,
}

Enemy_Template_Flags :: bit_set[Enemy_Template_Flag]
Enemy_Template_Flag  :: enum {
    DONT_WALK_OFF_LEDGES,
    IMMUNE_TO_FIRE,
    SPIKED,
    WINGED,
    HAS_PROJECTILE,
    STAY_FACING_PLAYER,
    NO_COLLIDE_TILEMAPS,
}

Enemy_Template :: struct {
    name             : string,
    uuid             : u64,
    
    flags            : Enemy_Flags,
    
    movement_style   : enum { GOOMBA, HAMMER_BRO, PATH },
    movement_speed   : f32,
    
    // collide_player   : proc(^player, ^entity)
    
    // for now, we presume this is always the same.
    // if need be in the future, we can probably just put the collision data in the animation
    collision_size   : Vector2,
    collision_offset : Vector2,
    
    // shell: struct {
        
    // }
    
    // projectile: struct {
    //     entity            : ^Entity_Template,
    //     velocity          : Vector2,
    //     velocity_variance : Vector2,
    // }
    
    animations: [Enemy_Animation_State] Simple_Animation,
}

Enemy_Animation_State :: enum {
    WALK,
    JUMP,
    FALL,
    WAKING_UP, // when a shelled entity is waking up out of his shell
    SHELL,
    CRUSHED,
    DEAD,
}

Enemy_Animator :: Simple_Animator(Enemy_Animation_State)

update_enemy :: proc(using enemy: ^Enemy) -> bool {
    if enemy == nil || enemy.template == nil do return true
    
    // general movement / behaviour
    {
        friction : f32 = .ON_GROUND in flags ? 0.9 : 1
        velocity.x *= friction
        
        velocity.y = min(Plumber_Physics.max_fall_speed, velocity.y + Plumber_Physics.fall_gravity) 
        
        if walk_dir == .L {
            position.x -= GOOMBA_WALK_SPEED 
        } else if walk_dir == .R {
            position.x += GOOMBA_WALK_SPEED 
        }
        
        position += velocity
    }

    // collision with tilemap
    {
        tilemap := &GameState.active_level.tilemap
        using collision_result := do_tilemap_collision(tilemap, position, template.collision_size, template.collision_offset)
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
                // block_hit_entity(cast(^Entity)goomba, bump_dir)
                break
            }
        }
    }
    
    // collision with plumber
    
    // collision with other entities (do this in its own update loop? maybe later)
    
    // update animator
    {
        animator.state = .WALK
    
        current_animation := &template.animations[animator.state]
        animator.current_frame = clamp(animator.current_frame, 0, len(current_animation.frames) - 1)
        current_frame := &current_animation.frames[animator.current_frame]
        
        // TODO probably add a step variable in animator to control direction/speed of animation
        // frame clock or current frame will need to be float
        
        animator.frame_clock += 1
        if animator.frame_clock >= current_frame.duration {
            animator.frame_clock = 0
            animator.current_frame += 1
            if animator.current_frame >= len(current_animation.frames) {
                if .LOOP in current_animation.flags {
                    animator.current_frame = 0
                }
            }
        }
    }
    
    return true
}

render_enemy :: proc(using enemy: Enemy, render_unit: f32, offset: Vector2) {
    if enemy.template == nil do return 

    current_animation := &template.animations[animator.state]
    current_frame     := &current_animation.frames[animator.current_frame]
    
    clip := current_frame.clip
    rect := sdl.Rect {
        x = i32((position.x + current_frame.offset.x + offset.x) * render_unit),
        y = i32((position.y + current_frame.offset.y + offset.y) * render_unit),
        w = i32((cast(f32) clip.w) / 16.0 * render_unit),
        h = i32((cast(f32) clip.h) / 16.0 * render_unit),
    }

    sdl.RenderCopyEx(renderer, entities_texture.sdl_texture, &clip, &rect, 0, nil, current_frame.flip)
    
    if show_enemy_collision_rects {
        sdl.SetRenderDrawColor(renderer, 0xff, 0x00, 0xff, 0xff)
        collision_rect := sdl.Rect {
            x = i32((position.x + template.collision_offset.x + offset.x) * render_unit),
            y = i32((position.y + template.collision_offset.y + offset.y) * render_unit),
            w = i32(template.collision_size.x * render_unit),
            h = i32(template.collision_size.y * render_unit),
        }
        sdl.RenderDrawRect(renderer, &collision_rect)
    }
}

get_enemy_collision_rect :: proc(using enemy: Enemy) -> (sdl.Rect) {
    return sdl.Rect {
        x = i32(position.x + template.collision_offset.x),
        y = i32(position.x + template.collision_offset.y),
        w = i32(template.collision_size.x),
        h = i32(template.collision_size.y),
    }
}

// not used in render_enemy, because we need the other info in current_frame
// will probably use this for the preview in editor
get_enemy_render_clip :: proc(using enemy: Enemy) -> (sdl.Rect) {
    current_animation := &template.animations[animator.state]
    current_frame     := &current_animation.frames[animator.current_frame]
    return current_frame.clip
}

get_enemy_template_icon_clip :: proc(using template: Enemy_Template, crop_x, crop_y: int) -> sdl.Rect {
    walk_animation := template.animations[.WALK]
    if len(walk_animation.frames) == 0 do return {}
    clip := walk_animation.frames[0].clip
    clip.x = cast(i32) min(int(clip.x), crop_x)
    clip.y = cast(i32) min(int(clip.x), crop_y)
    return clip
}

init_enemy :: proc(enemy: ^Enemy, template: ^Enemy_Template) {
    enemy.template = template
    enemy.walk_dir = .L
}