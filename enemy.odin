package main

import sdl "vendor:sdl2"
import "core:fmt"


Enemy :: struct  {
    template: ^Enemy_Template, // readonly at level runtime!
    
    flags: Enemy_Flags,
    
    
    
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
    flags            : Enemy_Flags,
    
    movement_style   : enum { GOOMBA, HAMMER_BRO, PATH }
    movement_speed   : f32,
    
    collide_player   : proc(^player, ^entity)
    collision_size   : Vector2
    collision_offset : Vector2
    
    render_offset    : Vector2

    // shell: struct {
        
    // }
    
    // projectile: struct {
    //     entity            : ^Entity_Template,
    //     velocity          : Vector2,
    //     velocity_variance : Vector2,
    // }
    
    // animations are stored in static template, animator is in each enemy instance
    animations: [Enemy_Animation_State] Simple_Animation
}

Enemy_Animation_State :: enum {
    .WALK,
    .JUMP,
    .FALL,
    .WAKING_UP, // when a shelled entity is waking up out of his shell
    .SHELL,
}

Enemy_Animator :: Simple_Animator(Enemy_Animation_State)

Simple_Animator :: struct(Anim_Enum: type) when reflect.type_is_enum(Anim_Enum) {
    state         : Anim_Enum,
    current_frame : int,
    frame_clock   : int,
}

Simple_Animation_Flags :: bit_set[Simple_Animation_Flag]
Simple_Animation_Flag  :: enum {
    LOOP,
    REVERSE,
}

Simple_Animation :: struct {
    frames : [dynamic] Simple_Animation_Frame,
    flags  : Simple_Animation_Flags,
}

Simple_Animation_Frame :: struct {
    clip     : sdl.Rect,
    duration : int,
},


update_enemy :: proc(using enemy: ^Enemy) {
    if enemy == nil do return
    
    

}

render_enemy :: proc(using enemy: Enemy) {
    

}