package main

import sdl "vendor:sdl2"
import "core:fmt"
import "core:math"
import "core:math/rand"

show_enemy_collision_rects := false

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

// unload_enemy_templates :: proc() {
//     clear(&enemy_templates)
//     for &t in enemy_templates {
//         for &a in t.animations {
//             delete(&a.frames)
//         }
//         delete(&t.animations)
//     }
//     clear(&enemy_templates)
// }

// Unfortunately can't make functions to load this stuff from GON easily until I add proper support for enumerated arrays
// so thanks a lot to Odin for adding needless complications to the type system
// I would just make the animations not be indexed by enums, but that means adding COUNT values to all my enums and changing the animator's implementation to be worse. so no thanks

// load_enemy_templates :: proc() -> bool {
//     unload_enemy_templates()
    
//     file, ok := os.read_entire_file("data/enemy_templates.gon")
//     if !ok {
//         fmt.println("Unable to open enemy templates file!")
//         return false
//     }
//     defer delete(file)
    
//     gon.set_file_to_parse(&ctxt, string(file))
//     gon.add_data_binding(&ctxt, enemy_templates, "enemies")
    
//     if !gon.SAX_parse_file(&ctxt) {
//         fmt.println("Unable to parse enemy templates!")
//         return false
//     }
    
//     return true
// }

STANDARD_SHELL_SPEED :: 0.125

init_enemy_templates :: proc() {
    goomba: Enemy_Template
    {
        using goomba
        
        name = "Goomba"
        
        movement_style = .GOOMBA
        movement_speed = 0.025
        
        collision_size   = { 14.0 / 16.0, 14.0 / 16.0 }
        collision_offset = -(collision_size / 2)
        
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
        
        animations[.JUMP] = animations[.WALK]
        animations[.FALL] = animations[.WALK]
        
        append(&animations[.CRUSHED].frames, Simple_Animation_Frame {
            offset = { -0.5, -0.5 },
            clip   = { 16, 0, 16, 16 },
            duration = 30,
        })
        
        animations[.DEAD].flags |= { .LOOP }
        append(&animations[.DEAD].frames, Simple_Animation_Frame {
            offset = { -0.5, -0.5 },
            clip   = { 0, 0, 16, 16 },
            flip   = .VERTICAL,
        })
        
    }
    append(&enemy_templates, goomba)
    
    galoomba: Enemy_Template
    {
        using galoomba
        
        name = "Galoomba"
        
        movement_style = .GOOMBA
        movement_speed = 0.025
        
        collision_size   = { 14.0 / 16.0, 14.0 / 16.0 }
        collision_offset = -(collision_size / 2)
        
        flags |= { .DONT_WALK_OFF_LEDGES }
        
        animations[.WALK].flags |= { .LOOP }
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 0, 16, 16, 16 },
            duration = 20,
        })
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 0, 16, 16, 16 },
            flip     = .HORIZONTAL,
            duration = 20,
        })
        
        append(&animations[.CRUSHED].frames, Simple_Animation_Frame {
            offset = { -0.5, -0.5 },
            clip   = { 16, 16, 16, 16 },
            duration = 30,
        })
        
        animations[.DEAD].flags |= { .LOOP }
        append(&animations[.DEAD].frames, Simple_Animation_Frame {
            offset = { -0.5, -0.5 },
            clip   = { 0, 16, 16, 16 },
            flip   = .VERTICAL,
        })
        
    }
    append(&enemy_templates, galoomba)
    
    green_koopa: Enemy_Template
    {
        using green_koopa
        
        name = "Koopa"
        
        movement_style = .GOOMBA
        movement_speed = 0.025
        
        collision_size   = { 14.0 / 16.0, 14.0 / 16.0 }
        collision_offset = -(collision_size / 2)
        
        flags |= { .SHELLED }
        
        shell.speed = STANDARD_SHELL_SPEED
        
        wings.type = .JUMP
        wings.jump.force = 0.2
        
        animations[.WALK].flags |= { .LOOP }
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 0, 32, 16, 24 },
            duration = 20,
        })
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 16, 32, 16, 24 },
            duration = 20,
        })
        animations[.JUMP] = animations[.WALK]
        animations[.FALL] = animations[.WALK]
        
        animations[.WINGED].flags |= { .LOOP }
        append(&animations[.WINGED].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 32, 32, 16, 24 },
            duration = 20,
        })
        append(&animations[.WINGED].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 48, 32, 16, 24 },
            duration = 20,
        })
        
        animations[.SHELL].flags |= { .LOOP }
        append(&animations[.SHELL].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 64, 40, 16, 16 },
            duration = 5,
        })
        append(&animations[.SHELL].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 80, 40, 16, 16 },
            duration = 5,
        })
        append(&animations[.SHELL].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 96, 40, 16, 16 },
            duration = 5,
        })
        append(&animations[.SHELL].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 112, 40, 16, 16 },
            duration = 5,
        })
        
        animations[.DEAD].flags |= { .LOOP }
        append(&animations[.DEAD].frames, Simple_Animation_Frame {
            offset = { -0.5, -0.5 },
            clip   = { 64, 40, 16, 16 },
            flip   = .VERTICAL,
        })
        
    }
    append(&enemy_templates, green_koopa)
     
    red_koopa := green_koopa
    {
        using red_koopa
        
        name = "Red Koopa"
        
        movement_style = .GOOMBA
        movement_speed = 0.025
        
        collision_size   = { 14.0 / 16.0, 14.0 / 16.0 }
        collision_offset = -(collision_size / 2)
        
        flags |= { .DONT_WALK_OFF_LEDGES }
        
        // clone animations from green koopa and add offset to clips
        for &anim, anim_index in animations {
            anim.frames = {}
            append(&anim.frames, ..green_koopa.animations[anim_index].frames[:])
            for &frame in anim.frames {
                frame.clip.y += 24
            }
        }
    }
    append(&enemy_templates, red_koopa)
    
    beetle: Enemy_Template
    {
        using beetle
        
        name = "Beetle"
        
        movement_style = .GOOMBA
        movement_speed = 0.025
        
        collision_size   = { 14.0 / 16.0, 14.0 / 16.0 }
        collision_offset = -(collision_size / 2)
        
        flags |= { .SHELLED, .IMMUNE_TO_FIRE }
        
        shell.speed = STANDARD_SHELL_SPEED
        
        wings.type = .BEETLE
        wings.beetle.speed = 0.1
        wings.beetle.acceleration = 0.0025
        
        animations[.WALK].flags |= { .LOOP }
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 0, 96, 16, 16 },
            duration = 20,
        })
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 16, 96, 16, 16 },
            duration = 20,
        })
        
        animations[.WINGED].flags |= { .LOOP }
        append(&animations[.WINGED].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 32, 96, 16, 16 },
            duration = 20,
        })
        append(&animations[.WINGED].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 48, 96, 16, 16 },
            duration = 20,
        })
        animations[.JUMP] = animations[.WALK]
        animations[.FALL] = animations[.WALK]
        
        animations[.SHELL].flags |= { .LOOP }
        append(&animations[.SHELL].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 64, 96, 16, 16 },
            duration = 5,
        })
        append(&animations[.SHELL].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 80, 96, 16, 16 },
            duration = 5,
        })
        append(&animations[.SHELL].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 96, 96, 16, 16 },
            duration = 5,
        })
        append(&animations[.SHELL].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 112, 96, 16, 16 },
            duration = 5,
        })
        
        animations[.DEAD].flags |= { .LOOP }
        append(&animations[.DEAD].frames, Simple_Animation_Frame {
            offset = { -0.5, -0.5 },
            clip   = { 64, 96, 16, 16 },
            flip   = .VERTICAL,
        })
        
    }
    append(&enemy_templates, beetle)
    
    spiny: Enemy_Template
    {
        using spiny
        
        name = "Spiny"
        
        movement_style = .GOOMBA
        movement_speed = 0.025
        
        collision_size   = { 14.0 / 16.0, 14.0 / 16.0 }
        collision_offset = -(collision_size / 2)
        
        flags |= { .SHELLED, .SPIKED }
        
        shell.speed = STANDARD_SHELL_SPEED
        
        wings.type = .BEETLE           
        wings.beetle.speed = 0.2
        wings.beetle.acceleration = 0.01
        
        animations[.WALK].flags |= { .LOOP }                  
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 0, 112, 16, 16 },
            duration = 20,
        })
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 16, 112, 16, 16 },
            duration = 20,
        })
        animations[.JUMP] = animations[.WALK]
        animations[.FALL] = animations[.WALK]
        
        animations[.WINGED].flags |= { .LOOP }
        append(&animations[.WINGED].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 32, 112, 16, 16 },
            duration = 20,
        })
        append(&animations[.WINGED].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 48, 112, 16, 16 },
            duration = 20,
        })
        
        animations[.SHELL].flags |= { .LOOP }
        append(&animations[.SHELL].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 64, 112, 16, 16 },
            duration = 5,
        })
        append(&animations[.SHELL].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 80, 112, 16, 16 },
            duration = 5,
        })
        append(&animations[.SHELL].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 96, 112, 16, 16 },
            duration = 5,
        })
        append(&animations[.SHELL].frames, Simple_Animation_Frame {
            offset   = { -0.5, -0.5 },
            clip     = { 112, 112, 16, 16 },
            duration = 5,
        })
        
        animations[.DEAD].flags |= { .LOOP }
        append(&animations[.DEAD].frames, Simple_Animation_Frame {
            offset = { -0.5, -0.5 },
            clip   = { 64, 112, 16, 16 },
            flip   = .VERTICAL,
        })
    }
    append(&enemy_templates, spiny)
    
    hammer_bro: Enemy_Template
    {
        using hammer_bro
        
        name = "Hammer Bro"
        
        movement_style = .HAMMER_BRO
        movement_speed = 0.025
        
        collision_size   = { 14.0 / 16.0, 14.0 / 16.0 }
        collision_offset = -(collision_size / 2)
        
        movement_range = 2.5
        jump_force = { 0.3, 0.45 }
        
        flags |= { .DONT_WALK_OFF_LEDGES, .STAY_FACING_PLAYER, .THROWS_THINGS }
        
        { 
            using throw
            entity_type = .PROJECTILE
            cooldown_range = { 30, 60 * 3 }
            
            using entity_params.projectile
            type              = .HAMMER
            velocity          = { 0.07, -0.4 } // velocity.x *= -1 when throw left
            velocity_variance = { 0.04,  0.2 }
            acceleration      = { 0, Plumber_Physics.fall_gravity }
            vel_min = { -1, -1, }
            vel_max = {  1, Plumber_Physics.max_fall_speed * 0.75, }
        }
        
        animations[.WALK].flags |= { .LOOP }
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 144, 32, 16, 24 },
            duration = 20,
        })
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 160, 32, 16, 24 },
            duration = 20,
        })
        
        append(&animations[.JUMP].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 144, 32, 16, 24 },
            duration = 20,
        })
        
        append(&animations[.THROW].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 176, 32, 16, 24 },
            duration = 5,
        })
        append(&animations[.THROW].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 192, 32, 16, 24 },
            duration = 5,
        })
        
        animations[.DEAD].flags |= { .LOOP }
        append(&animations[.DEAD].frames, Simple_Animation_Frame {
            offset = { -0.5, -1.0 },
            clip   = { 144, 32, 16, 24 },
            flip   = .VERTICAL,
        })
        
    }
    append(&enemy_templates, hammer_bro)
    
    fire_bro: Enemy_Template
    {
        using fire_bro
        
        name = "Fire Bro"
        
        movement_style = .HAMMER_BRO
        movement_speed = 0.025
        
        collision_size   = { 14.0 / 16.0, 14.0 / 16.0 }
        collision_offset = -(collision_size / 2)
        
        movement_range = 2.5
        jump_force = { 0.3, 0.45 }
        
        flags |= { .DONT_WALK_OFF_LEDGES, .STAY_FACING_PLAYER, .THROWS_THINGS }
        
        { 
            using throw
            entity_type = .PROJECTILE
            cooldown_range = { 30, 60 * 3 }
            
            using entity_params.projectile
            type              = .FIREBALL
            velocity          = { 0.1 , 0.05 } // velocity.x *= -1 when throw left
            velocity_variance = { 0.05, 0.1  }
            acceleration      = { 0, Plumber_Physics.fall_gravity }
            vel_min           = { -1, -1, }
            vel_max           = {  1, Plumber_Physics.max_fall_speed * 0.75, }
            flags             = { .BOUNCE_ON_FLOOR, .COLLIDE_TILEMAP, .DIE_ON_COLLIDE, .DIE_ON_WALLS }
        }
        
        animations[.WALK].flags |= { .LOOP }
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 144, 56, 16, 24 },
            duration = 20,
        })
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 160, 56, 16, 24 },
            duration = 20,
        })
        
        append(&animations[.JUMP].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 144, 56, 16, 24 },
            duration = 20,
        })
        
        append(&animations[.THROW].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 176, 56, 16, 24 },
            duration = 5,
        })
        append(&animations[.THROW].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 192, 56, 16, 24 },
            duration = 5,
        })
        
        animations[.DEAD].flags |= { .LOOP }
        append(&animations[.DEAD].frames, Simple_Animation_Frame {
            offset = { -0.5, -1.0 },
            clip   = { 144, 56, 16, 24 },
            flip   = .VERTICAL,
        })
        
    }
    append(&enemy_templates, fire_bro)
    
    spike_bro: Enemy_Template
    {
        using spike_bro
        
        name = "Spike Bro"
        
        movement_style = .HAMMER_BRO
        movement_speed = 0.025
        
        collision_size   = { 14.0 / 16.0, 14.0 / 16.0 }
        collision_offset = -(collision_size / 2)
        
        movement_range = 2.5
        jump_force = { 0.3, 0.45 }
        
        flags |= { .DONT_WALK_OFF_LEDGES, .STAY_FACING_PLAYER, .THROWS_THINGS }
        
        { 
            using throw
            entity_type = .PROJECTILE
            cooldown_range = { 60, 60 * 5 }
            
            using entity_params.projectile
            type              = .SPIKE_BALL
            velocity          = { 0.07, -0.2 } // velocity.x *= -1 when throw left
            velocity_variance = { 0.04,  0.1 }
            acceleration      = { 0, Plumber_Physics.fall_gravity }
            vel_min = { -1, -1, }
            vel_max = {  1, Plumber_Physics.max_fall_speed * 0.75, }
            flags = { .BOUNCE_ON_WALLS, .BOUNCE_ON_FLOOR, .COLLIDE_TILEMAP }
        }
        
        animations[.WALK].flags |= { .LOOP }
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 144, 80, 16, 24 },
            duration = 20,
        })
        append(&animations[.WALK].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 160, 80, 16, 24 },
            duration = 20,
        })
        
        append(&animations[.JUMP].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 144, 80, 16, 24 },
            duration = 20,
        })
        
        append(&animations[.THROW].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 176, 80, 16, 24 },
            duration = 5,
        })
        append(&animations[.THROW].frames, Simple_Animation_Frame {
            offset   = { -0.5, -1.0 },
            clip     = { 192, 80, 16, 24 },
            duration = 5,
        })
        
        animations[.DEAD].flags |= { .LOOP }
        append(&animations[.DEAD].frames, Simple_Animation_Frame {
            offset = { -0.5, -1.0 },
            clip   = { 144, 80, 16, 24 },
            flip   = .VERTICAL,
        })
        
    }
    append(&enemy_templates, spike_bro)
}

Enemy :: struct  {
    using base: Entity_Base,

    template_index : int,
    flags          : Enemy_Flags,
    animator       : Enemy_Animator,
    
    walk_dir            : Direction,
    player_ignore_clock : int,

    // used to keep hammer bro types within a set area
    // could also be used to reset entities that wander off screen without being killed, if we wanted to do that
    init_position : Vector2,
    jump_clock    : int,

    shell: struct {
        clock       : int,
        score_combo : int,
    },
    
    throw: struct {
        clock : int,
    },
}

Enemy_Flags :: bit_set[Enemy_Flag]
Enemy_Flag  :: enum {
    // general states
    ON_GROUND,
    DEAD,
    CRUSHED,
    WINGED,

    // shell flags
    MOVING,
    FLIPPED,
    
    NO_COLLIDE_TILEMAP,
    PLAYER_STANDING_ON,
}

Enemy_Template_Flags :: bit_set[Enemy_Template_Flag]
Enemy_Template_Flag  :: enum {
    DONT_WALK_OFF_LEDGES,
    IMMUNE_TO_FIRE,
    SHELLED,
    SPIKED,
    WINGED,
    THROWS_THINGS,
    STAY_FACING_PLAYER,
    NO_COLLIDE_TILEMAP,
}

Enemy_Template :: struct {
    name             : string,
    uuid             : u64,
    
    flags            : Enemy_Template_Flags,
    
    movement_style   : enum { GOOMBA, HAMMER_BRO },
    movement_speed   : f32,
    movement_range   : f32, // defines the distance that a hammer bro will stray from starting x position
    
    // for now, we presume this is always the same.
    // if need be in the future, we can probably just put the collision data in the animation
    collision_size   : Vector2,
    collision_offset : Vector2,
    
    jump_force : [2]f32, // min and max
    
    wings : struct {
        type : enum { JUMP, VERTICAL, HORIZONTAL, SEEKING, BEETLE },
        using params: struct #raw_union {
            jump       : struct { force: f32 }, // remove and use jump_force instead? or replace this with a multiplier?
            vertical   : struct { range, speed: f32 },
            horizontal : struct { range, speed: f32 },
            seeking    : struct { acceleration, speed: f32 },
            beetle     : struct { acceleration, speed: f32 },
        }
    },
    
    shell : struct {
        speed : f32,
    },
    
    throw : struct {
        cooldown_range : [2] i32,
        entity_type : Entity_Type,
        entity_params: struct #raw_union {
            item : struct {
                type              : Item_Type,
                flags             : Item_Flags,
                velocity          : Vector2,
                velocity_variance : Vector2,
            },
            enemy: struct {
                template          : int,
                velocity          : Vector2,
                velocity_variance : Vector2,
            },
            projectile: struct {
                type                  : Projectile_Type,
                flags                 : Projectile_Flags,
                velocity              : Vector2,
                velocity_variance     : Vector2,
                acceleration          : Vector2,
                friction              : Vector2,
                vel_min               : Vector2,
                vel_max               : Vector2,
            },
        },
    },
    
    animations: [Enemy_Animation_State] Simple_Animation,
}

Enemy_Animation_State :: enum {
    WALK,
    JUMP,
    FALL,
    SHELL,
    WINGED,
    CRUSHED,
    THROW,
    DEAD,
}

Enemy_Animator :: Simple_Animator(Enemy_Animation_State)

update_enemy :: proc(using enemy: ^Enemy) -> bool {
    if enemy == nil do return true
    template := &enemy_templates[enemy.template_index]
    
    if position_prev == {} do init_position = position // this is very dumb, but maybe works in practice?
    
    position_prev = position
    
    // skip updating enemies not on the screen
    if position.x < GameState.active_level.camera.position.x - SCREEN_TILE_WIDTH / 2 ||
       position.x > GameState.active_level.camera.position.x + SCREEN_TILE_WIDTH + 2 {
        return true
    }
    
    // check if the enemy has fallen out of the level
    if position.y > SCREEN_TILE_HEIGHT + 2 {
        entity_flags |= { .REMOVE_ME }
        return false
    }
    
    do_movement         := true
    do_collide_tilemap  := true
    do_collide_plumber  := true
    do_collide_entities := true
    
    if .NO_COLLIDE_TILEMAP in flags || .NO_COLLIDE_TILEMAP in template.flags {
        do_collide_tilemap = false
    }
    
    if .DEAD in flags {
        do_movement         = false
        do_collide_plumber  = false
        do_collide_entities = false
        if .STOPPED in animator.flags {
            entity_flags |= { .REMOVE_ME }
            return false
        }
    }
    
    player_ignore_clock = max(player_ignore_clock - 1, 0)
    
    if is_enemy_in_shell(enemy^) {
        if .MOVING not_in flags {
            shell.clock -= 1
            if shell.clock == 0 {
                flags &= ~{ .FLIPPED }
            }
        }
    }
    
    applied_gravity := Plumber_Physics.fall_gravity

    if do_movement {
        movement_speed := template.movement_speed
        if is_enemy_in_shell(enemy^) {
            if .MOVING in flags {
                movement_speed = template.shell.speed
            } else {
                movement_speed = 0
            }
        }
        
        // if walk dir is not valid and enemy is on the ground, 
        // then pick the direction to walk based on current velocity
        // this behaviour is used intentionally when items/enemies pop out of item blocks
        if walk_dir not_in (Directions { .L, .R }) {
            if .ON_GROUND in flags {
                walk_dir = velocity.x > 0 ? .R : .L 
            }
        }
        
        if template.movement_style == .HAMMER_BRO {
            if      position.x < init_position.x - template.movement_range do walk_dir = .R
            else if position.x > init_position.x + template.movement_range do walk_dir = .L
            
            if .ON_GROUND in flags {
                jump_clock -= 1
                if jump_clock <= 0 {
                    velocity.y -= lerp(template.jump_force[0], template.jump_force[1], rand.float32())
                    jump_clock = int(60 + rand.int63_max(60 * 9))
                }
            }
        }
        
        #partial switch walk_dir {
            case .L: position.x -= movement_speed
            case .R: position.x += movement_speed
        }
        
        if .WINGED in flags {
            #partial switch template.wings.type {
                case .JUMP:
                    applied_gravity /= 2
                    if .ON_GROUND in flags {
                        velocity.y -= template.wings.jump.force
                    }
                case .BEETLE: 
                    applied_gravity = 0
                    if .PLAYER_STANDING_ON in flags {
                        velocity.y = max(-template.wings.beetle.speed, velocity.y - template.wings.beetle.acceleration)
                    } else {
                        velocity.y *= 0.8
                    }
            }
        }
        
        if .THROWS_THINGS in template.flags {
            throw.clock -= 1
            if throw.clock <= 0 {
                slot := get_next_empty_slot(&GameState.active_level.entities)
                if slot != nil {
                    slot.occupied = true
                    using template.throw
                    facing_mul := get_enemy_facing_vector(enemy^)
                    #partial switch entity_type {
                        case .PROJECTILE:
                            projectile := cast(^Projectile) &slot.data
                            init_projectile(projectile, entity_params.projectile.type)
                            {
                                using projectile
                                position     = enemy.position + { 0.5 * facing_mul, -0.5 } // TODO: add throw offset in template
                                velocity     = (entity_params.projectile.velocity * { facing_mul, 1 }) + (entity_params.projectile.velocity_variance * ({ rand.float32() - 0.5, rand.float32() - 0.5 }))
                                acceleration = entity_params.projectile.acceleration
                                vel_min      = entity_params.projectile.vel_min
                                vel_max      = entity_params.projectile.vel_max
                                flags        = entity_params.projectile.flags | { .COLLIDE_PLAYER }
                                // TODO: maybe we want some way for the projectile to ignore entity who spawned it for a limited time? may be tricky
                            }
                            fmt.println(projectile)
                        
                    }
                    throw.clock = int(cooldown_range[0] + rand.int31_max(cooldown_range[1] - cooldown_range[0]))
                }
            }
        }
    }
    
    friction : f32 = .ON_GROUND in flags ? 0.9 : 1
    velocity.x *= friction
    
    velocity.y = min(Plumber_Physics.max_fall_speed, velocity.y + applied_gravity) 
    position += velocity

    flags &= ~{ .ON_GROUND, .PLAYER_STANDING_ON }
    
    if do_collide_tilemap {
        tilemap := &GameState.active_level.tilemap
        using collision_result := do_tilemap_collision(tilemap, position, template.collision_size, template.collision_offset)
        position += position_adjust
        if .L in push_out {
            if walk_dir == .L do walk_dir = .R
            if is_enemy_in_shell(enemy^) && .MOVING in flags {
                bump_tile(tilemap, indexed_tiles[push_out_dir[Direction.L]], .SHELL, .L)
            }
        }
        if .R in push_out {
            if walk_dir == .R do walk_dir = .L
            if is_enemy_in_shell(enemy^) && .MOVING in flags {
                bump_tile(tilemap, indexed_tiles[push_out_dir[Direction.R]], .SHELL, .R)
            }
        }
        if .U in push_out {
            if velocity.y < 0 do velocity.y = Plumber_Physics.hit_ceiling
        }
        if .D in push_out {
            if velocity.y > 0 do velocity.y = 0
            flags |= { .ON_GROUND }
            
            if .DONT_WALK_OFF_LEDGES in template.flags && !is_enemy_in_shell(enemy^) {
                x_frac := (position.x - math.floor(position.x))
                if .DL not_in push_out && walk_dir == .L && x_frac < 0.25 do walk_dir = .R
                if .DR not_in push_out && walk_dir == .R && x_frac > 0.75 do walk_dir = .L
            }
        }
        
        // handle getting hit from below by a bumped tile
        for dir in ([]Direction {.D, .DL, .DR}) {
            tile := get_tile(tilemap, indexed_tiles[dir])
            if tile != nil && tile_is_bumping(tile^) {
                // bump_dir := dir
                // if bump_dir == .D {
                    bump_dir := walk_dir
                // }
                
                bump_vel := Vector2 { 0, -0.25 }
                if bump_dir == .L { // these are sorta flipped bc of how we get the sides in entity code. should change this probably
                    bump_vel.x = -0.05
                } else if bump_dir == .R {
                    bump_vel.x = 0.05
                }
                
                velocity += bump_vel
                
                if .SHELLED in template.flags {
                    flags ~= { .FLIPPED }
                    flags &= ~{ .MOVING }
                    shell.clock = 60 * 5
                    player_ignore_clock = 3
                } else {
                    flags |= { .DEAD, .NO_COLLIDE_TILEMAP }
                }
                
                break
            }
        }
    }
    
    if do_collide_plumber && player_ignore_clock == 0 {
        plumber := &GameState.active_level.plumber
        enemy_collide_plumber(enemy, plumber)
    }
    
    // collision with other entities (do this in its own update loop? maybe later)
    for &slot, i in GameState.active_level.entities.slots {
        if slot.occupied {
            other := &slot.data
            if uintptr(enemy) == uintptr(other) do continue
                enemy_rect := get_entity_collision_rect((cast(^Entity)enemy)^)
                other_rect := get_entity_collision_rect(other^)
                if aabb_frect(enemy_rect, other_rect) {
                    if is_enemy_in_shell(enemy^) && .MOVING in flags {
                        if shell_hit_entity(&slot.data) {
                            plumber_add_combo_points(&GameState.active_level.plumber, &shell.score_combo, other.base.position)
                        }
                    }
                }
        }
    }
        
    return true
}

render_enemy :: proc(using enemy: ^Enemy, render_unit: f32, offset: Vector2, alpha_mod: f32 = 1) {
    if enemy.template_index < 0 || enemy.template_index > len(enemy_templates) do return
    template := &enemy_templates[enemy.template_index]

    update_enemy_animator(enemy)

    current_animation := &template.animations[animator.state]
    current_frame     := &current_animation.frames[animator.current_frame]
    
    flip := current_frame.flip
    
    if .STAY_FACING_PLAYER in template.flags {
        if GameState.active_level.plumber.position.x > position.x {
            flip |= .HORIZONTAL
        } else {
            flip &~= .HORIZONTAL
        }
    } else if walk_dir == .R {
        flip ~= .HORIZONTAL
    }
    
    if .FLIPPED in flags {
        flip |= .VERTICAL
    }
    
    clip := current_frame.clip
    rect := sdl.Rect {
        x = i32((position.x + current_frame.offset.x + offset.x) * render_unit),
        y = i32((position.y + current_frame.offset.y + offset.y) * render_unit),
        w = i32((cast(f32) clip.w) / 16.0 * render_unit),
        h = i32((cast(f32) clip.h) / 16.0 * render_unit),
    }
    
    // make the shell shake when the enemy is about to unshell
    if shell.clock > 0 && shell.clock < 60 {
        offset := (1.0 / 16.0) * render_unit
        mod := (shell.clock / 2) % 4
        if mod == 1 do rect.x += i32(offset)
        if mod == 3 do rect.x -= i32(offset)
    }
    
    sdl.SetTextureAlphaMod(entities_texture.sdl_texture, u8(alpha_mod * 255))
    sdl.RenderCopyEx(renderer, entities_texture.sdl_texture, &clip, &rect, 0, nil, flip)
    sdl.SetTextureAlphaMod(entities_texture.sdl_texture, 0xFF)
    
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

get_enemy_collision_rect :: proc(using enemy: Enemy) -> (sdl.FRect) {
    if enemy.template_index < 0 || enemy.template_index > len(enemy_templates) do return {}
    template := &enemy_templates[enemy.template_index]
    return {
        x = (position.x + template.collision_offset.x),
        y = (position.y + template.collision_offset.y),
        w = (template.collision_size.x),
        h = (template.collision_size.y),
    }
}

// not used in render_enemy, because we need the other info in current_frame
// will probably use this for the preview in editor
get_enemy_render_clip :: proc(using enemy: Enemy) -> (sdl.Rect) {
    if enemy.template_index < 0 || enemy.template_index > len(enemy_templates) do return {}
    template := &enemy_templates[enemy.template_index]
    current_animation := &template.animations[animator.state]
    current_frame     := &current_animation.frames[animator.current_frame]
    return current_frame.clip
}

get_enemy_template_icon_clip :: proc(using template: Enemy_Template, crop_x, crop_y: int) -> sdl.Rect {
    walk_animation := template.animations[.WALK]
    if len(walk_animation.frames) == 0 do return {}
    clip := walk_animation.frames[0].clip
    clip.w = cast(i32) min(int(clip.w), crop_x)
    clip.h = cast(i32) min(int(clip.h), crop_y)
    return clip
}

init_enemy :: proc(enemy: ^Enemy, template_index: int, walk_dir: Direction = .L) {
    enemy.entity_type    = .ENEMY
    enemy.template_index = template_index
    enemy.walk_dir       = walk_dir
    enemy.animator.state = .WALK
}

// return true if we should count points for hitting the enemy
// we give this info back to caller to handle so that we can handle multi-enemy combos
shell_hit_enemy :: proc(using enemy: ^Enemy) -> bool {
    template := &enemy_templates[template_index]
    if .DEAD not_in flags {
        flags |= { .DEAD, .NO_COLLIDE_TILEMAP }
        velocity.y -= 0.25
        return true
    }
    return false
}

fireball_hit_enemy :: proc(using enemy: ^Enemy) -> bool {
    template := &enemy_templates[template_index]
    
    if .IMMUNE_TO_FIRE in template.flags do return false
    if .DEAD           in flags          do return false
    
    flags |= { .DEAD, .NO_COLLIDE_TILEMAP }
    velocity.y -= 0.25
    plumber_add_points(&GameState.active_level.plumber, 0, position)
    return true
}

is_enemy_in_shell :: #force_inline proc(using enemy: Enemy) -> bool {
    return shell.clock > 0
}

update_enemy_animator :: proc(using enemy: ^Enemy) {
    if template_index < 0 || template_index > len(enemy_templates) do return
    template := &enemy_templates[template_index]
    
    update_enemy_animation_state(enemy)
    step_animator(&animator, &template.animations)
}

update_enemy_animation_state :: proc(using enemy: ^Enemy) {
    template := &enemy_templates[enemy.template_index]
    if .CRUSHED in flags {
        maybe_set_animation(&animator, Enemy_Animation_State.CRUSHED, &template.animations)
    }
    else if .DEAD in flags {
        set_animation(&animator, Enemy_Animation_State.DEAD)
    } 
    else if .WINGED in flags {
        set_animation(&animator, Enemy_Animation_State.WINGED)
    } 
    else if is_enemy_in_shell(enemy^) {
        set_animation(&animator, Enemy_Animation_State.SHELL)
        if .MOVING not_in flags {
            animator.flags |= { .STOPPED }
            animator.current_frame = 0
        } else {
            animator.flags &= ~{ .STOPPED }
        }
    } 
    else if .ON_GROUND not_in flags {
        if velocity.x < 0 {
            maybe_set_animation(&animator, Enemy_Animation_State.JUMP, &template.animations)
        } else {
            maybe_set_animation(&animator, Enemy_Animation_State.FALL, &template.animations)
        }
    } 
    else {
        set_animation(&animator, Enemy_Animation_State.WALK)
    }
}

enemy_collide_plumber :: proc(using enemy: ^Enemy, plumber: ^Plumber) {
    template := &enemy_templates[enemy.template_index]
    
    p_rect := get_plumber_collision_rect(plumber^)
    e_rect := get_enemy_collision_rect(enemy^)
    
    if aabb_frect(p_rect, e_rect) {
        stomp_margin :: 2.0 / 16.0 // 2 pixels
        is_stomped := p_rect.y + p_rect.h - max(0, plumber.velocity.y) < e_rect.y + stomp_margin
        
        do_player_bounce :=  is_stomped
        do_player_damage := !is_stomped
        
        if .WINGED in flags {
            if is_stomped {
                #partial switch template.wings.type {
                    case .JUMP:
                        flags &= ~{ .WINGED }
                        if velocity.y < 0 do velocity.y = 0
                        
                    case .BEETLE:
                        if .PLAYER_STANDING_ON in flags {
                            velocity.y = 0.3
                        }
                        flags |= { .PLAYER_STANDING_ON }
                        do_player_bounce = false
                        
                        plumber.position.y -= max(0, (p_rect.y + p_rect.h) - e_rect.y)
                        if plumber.velocity.y > 0 do plumber.velocity.y = 0
                        plumber.flags |= { .ON_GROUND }
                        plumber.ground_velocity = position - position_prev
                }
            }
            if .SPIKED in template.flags {
                do_player_damage = true
                do_player_bounce = false
            }
        } else {
            if .SHELLED in template.flags {
                // if enemy is in shell and not moving, then it can be kicked
                if is_enemy_in_shell(enemy^) && .MOVING not_in flags {
                    do_player_damage = false
                    if .SPIKED in template.flags {
                        // player is damaged by landing on the spiky side of shell, or by spiky side of shell landing on player's head
                        // the sides of a spiked shell do not harm the player
                        do_player_damage = (.FLIPPED not_in flags && is_stomped) || (.FLIPPED in flags && e_rect.y + e_rect.h - max(0, velocity.y) < p_rect.y + stomp_margin)
                    }
                    
                    do_player_bounce = false
                    
                    flags |= { .MOVING }
                    walk_dir = (plumber.position.x > position.x ? .L : .R)
                    player_ignore_clock = 20
                    
                    plumber.score += 400
                    spawn_score_particle(2, position)
                } else {
                    // stomping on a spiked enemy will not cause it to go into its shell, and the player will take damage
                    if is_stomped {
                        if .SPIKED in template.flags && .FLIPPED not_in flags {
                            do_player_damage = true
                            do_player_bounce = false
                        } else {
                            flags &= ~{ .MOVING }
                            shell.clock = 60 * 5
                            player_ignore_clock = 3
                        }
                    }
                }
            } else {
                if .SPIKED in template.flags && .FLIPPED not_in flags {
                    do_player_damage = true
                    do_player_bounce = false
                } else {
                    if is_stomped {
                        if len(template.animations[.CRUSHED].frames) > 0 {
                            flags |= { .CRUSHED, .DEAD }
                        } else {
                            flags |= { .DEAD, .NO_COLLIDE_TILEMAP }
                        }
                    }
                }
            }
        }
        
        if do_player_bounce {
            plumber.velocity.y = -Plumber_Physics.bounce_force
            plumber.position.y += plumber.velocity.y
            plumber_add_combo_points(plumber, &plumber.bounce_combo, position)
        }
        
        if do_player_damage {
            plumber_take_damage(plumber)
        }
    }
}

get_enemy_facing_direction :: proc(using enemy: Enemy) -> Direction {
    template := &enemy_templates[enemy.template_index]
    
    if .STAY_FACING_PLAYER in template.flags {
        if GameState.active_level.plumber.position.x > position.x {
            return .R
        }
        return .L
    }
    
    return walk_dir
}

// says vector, but really a float because 1d consideration
get_enemy_facing_vector :: #force_inline proc(enemy: Enemy) -> f32 {
    return get_enemy_facing_direction(enemy) == .L ? -1 : 1
}
