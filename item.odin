package main

import sdl "vendor:sdl2"
import "core:fmt"
import "core:math"

Item :: struct  {
    using base: Entity_Base,

    type     : Item_Type,
    flags    : Item_Flags,
    animator : Item_Animator,
    walk_dir : Direction,
}

Item_Type :: enum {
    COIN,
    SUPER_MUSHROOM,
    FIRE_FLOWER,
    // ONE_UP_MUSHROOM,
}

Item_Flags :: bit_set[Item_Flag]
Item_Flag  :: enum {
    ON_GROUND,
    PROGRESSIVE, // e.g., will spawn a fire flower as mushroom if player has no item yet
    WINGED,
}


Item_Animator :: Simple_Animator(Item_Type)

// for now, only one animation per item type
item_animations: [Item_Type] Simple_Animation

init_item_animations :: proc() {
    item_animations[.COIN].flags |= { .LOOP }
    append(&item_animations[.COIN].frames, Simple_Animation_Frame {
        offset   = { -0.25, -0.5 },
        clip     = { 112, 0, 8, 16 },
        duration = 5,
    })
    append(&item_animations[.COIN].frames, Simple_Animation_Frame {
        offset   = { -0.25, -0.5 },
        clip     = { 120, 0, 8, 16 },
        duration = 5,
    })
    append(&item_animations[.COIN].frames, Simple_Animation_Frame {
        offset   = { -0.25, -0.5 },
        clip     = { 128, 0, 8, 16 },
        duration = 5,
    })
    append(&item_animations[.COIN].frames, Simple_Animation_Frame {
        offset   = { -0.25, -0.5 },
        clip     = { 136, 0, 8, 16 },
        duration = 5,
    })
    
    append(&item_animations[.SUPER_MUSHROOM].frames, Simple_Animation_Frame {
        offset   = { -0.5, -0.5 },
        clip     = { 32, 0, 16, 16 },
    })
    
    item_animations[.FIRE_FLOWER].flags |= { .LOOP }
    append(&item_animations[.FIRE_FLOWER].frames, Simple_Animation_Frame {
        offset   = { -0.5, -0.5 },
        clip     = {  0, 80, 16, 16 },
        duration = 5,
    })
    append(&item_animations[.FIRE_FLOWER].frames, Simple_Animation_Frame {
        offset   = { -0.5, -0.5 },
        clip     = { 16, 80, 16, 16 },
        duration = 5,
    })
    append(&item_animations[.FIRE_FLOWER].frames, Simple_Animation_Frame {
        offset   = { -0.5, -0.5 },
        clip     = { 32, 80, 16, 16 },
        duration = 5,
    })
    append(&item_animations[.FIRE_FLOWER].frames, Simple_Animation_Frame {
        offset   = { -0.5, -0.5 },
        clip     = { 48, 80, 16, 16 },
        duration = 5,
    })
}

init_item :: proc(item: ^Item, type: Item_Type, walk_dir: Direction = .L) {
    item.entity_type = .ITEM
    item.type = type
    set_animation(&item.animator, item.type)
}

spawn_item :: proc(item: ^Item) {
    #partial switch item.type {
        case .FIRE_FLOWER:
            if .PROGRESSIVE in item.flags && GameState.active_level.plumber.powerup == .NONE {
                item.type = .SUPER_MUSHROOM
            }
    }
}

update_item :: proc(using item: ^Item) -> bool {
    if item == nil do return true
    plumber := &GameState.active_level.plumber

    if position.y > SCREEN_TILE_HEIGHT + 1 {
        entity_flags |= {.REMOVE_ME}
        return false
    }
    
    if type == .SUPER_MUSHROOM {
        #partial switch walk_dir {
            case .L: position.x -= 0.03
            case .R: position.x += 0.03
            
            // if walk dir is not valid, pick direction to walk based on current velocity
            // this behaviour is used intentionally when items/enemies pop out of item blocks
            case: if .ON_GROUND in flags do walk_dir = velocity.x > 0 ? .R : .L 
        }
    }
    
    friction : f32 = .ON_GROUND in flags ? 0.9 : 1
    velocity.x *= friction
    
    applied_gravity := Plumber_Physics.fall_gravity
    velocity.y = min(Plumber_Physics.max_fall_speed, velocity.y + applied_gravity) 
    
    position += velocity
    
    flags &= ~{ .ON_GROUND }
    
    // collide tilemap
    {
        tilemap := &GameState.active_level.tilemap
        size, offset := get_item_collision_size_and_offset(item^)
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
            flags |= { .ON_GROUND }
        }
        
        // handle getting hit from below by a bumped tile
        for dir in ([]Direction {.D, .DL, .DR}) {
            tile := get_tile(tilemap, indexed_tiles[dir])
            if tile != nil && tile_is_bumping(tile^) {
                #partial switch type {
                    // case .COIN:
                        // plumber_add_coins(plumber, 1, position)
                        // spawn_coin_particle(position)
                        // entity_flags |= { .REMOVE_ME }
                        // return false
                    case:
                        velocity.y -= 0.25
                }
                break
            }
        }
    }
    
    
    // collide player
    p_rect  := get_plumber_collision_rect(plumber^)
    e_rect  := get_item_collision_rect(item^)
    if aabb_frect(p_rect, e_rect) {
        #partial switch type {
            case .COIN:
                plumber_add_coins(plumber, 1, position)
                spawn_coin_particle(position)
                entity_flags |= { .REMOVE_ME }
                return false
            case .SUPER_MUSHROOM:
                change_plumber_powerup_state(plumber, .SUPER)
                plumber_add_points(plumber, 5, position)
                entity_flags |= { .REMOVE_ME }
                return false
            case .FIRE_FLOWER:
                change_plumber_powerup_state(plumber, .FIRE)
                plumber_add_points(plumber, 5, position)
                entity_flags |= { .REMOVE_ME }
                return false
        }
    }
    
    return true
}

render_item :: proc(using item: ^Item, render_unit: f32, offset: Vector2, alpha_mod: f32 = 1) {
    step_animator(&animator, &item_animations)

    current_animation := &item_animations[animator.state]
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

get_item_collision_size_and_offset :: proc(using item: Item) -> (size, offset: Vector2) {
    #partial switch type {
        case .COIN:
            return { 0.5, 1.0 }, { -0.25, -0.5 } 
        case:
            return { 1.0, 1.0 }, { -0.5, -0.5 } 
    }
}

get_item_collision_rect :: proc(using item: Item) -> sdl.FRect {
    size, offset := get_item_collision_size_and_offset(item)
    return {
        x = position.x + offset.x,
        y = position.y + offset.y,
        w = size.x,
        h = size.y,
    }
}

get_item_icon_clip :: proc(type: Item_Type, crop_x, crop_y: int) -> sdl.Rect {
    animation := item_animations[type]
    if len(animation.frames) == 0 do return {}
    clip := animation.frames[0].clip
    clip.w = cast(i32) min(int(clip.w), crop_x)
    clip.h = cast(i32) min(int(clip.h), crop_y)
    return clip
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

shell_hit_item :: proc(using item: ^Item) -> bool {
    #partial switch item.type {
        case .COIN:
            plumber_add_coins(&GameState.active_level.plumber, 1, position)
            spawn_coin_particle(position)
            item.entity_flags |= { .REMOVE_ME }
        case:
            velocity.y -= 0.25
    }
    return false
}