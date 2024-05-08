
package main

import sdl "vendor:sdl2"
import "core:fmt"

Simple_Animator :: struct(Anim_State: typeid) {
    state         : Anim_State,
    current_frame : int,
    frame_clock   : int,
    flags : Simple_Animator_Flags
}

Simple_Animator_Flags :: bit_set[Simple_Animator_Flag]
Simple_Animator_Flag  :: enum {
    STOPPED,
}

Simple_Animation_Flags :: bit_set[Simple_Animation_Flag]
Simple_Animation_Flag  :: enum {
    LOOP,
    REVERSE, // TODO 
}

Simple_Animation :: struct {
    frames : [dynamic] Simple_Animation_Frame,
    flags  : Simple_Animation_Flags,
}

Simple_Animation_Frame :: struct {
    clip     : sdl.Rect,
    flip     : sdl.RendererFlip,
    offset   : Vector2,
    duration : int,
}

// sets the animation state and always restarts the animation, disables .STOPPED flag
start_animation :: proc(animator: ^Simple_Animator($Anim_State), state: Anim_State) {
    animator.state         = state
    animator.current_frame = 0
    animator.frame_clock   = 0
    animator.flags &= ~{ .STOPPED }
}

// calls start_animation only if the desired state is different than the current state
set_animation :: proc(animator: ^Simple_Animator($Anim_State), state: Anim_State) {
    if animator.state != state {
        start_animation(animator, state)
    }
}

// won't change animation state if the desired animation state contains no frames
maybe_set_animation :: proc(animator: ^Simple_Animator($Anim_State), state: Anim_State, animations: ^[Anim_State] Simple_Animation) {
    if animator.state != state && len(animations[state].frames) > 0 {
        start_animation(animator, state)
    }
}

step_animator :: proc(animator: ^Simple_Animator($Anim_State), animations: ^[Anim_State] Simple_Animation) {
    current_animation := &animations[animator.state]
    // animator.current_frame = clamp(animator.current_frame, 0, len(current_animation.frames) - 1)
    current_frame := &current_animation.frames[animator.current_frame]

    if .STOPPED not_in animator.flags {
        // TODO probably add a step variable in animator to control direction/speed of animation
        // frame clock or current frame will need to be float
        animator.frame_clock += 1
        if animator.frame_clock >= current_frame.duration {
            animator.frame_clock = 0
            animator.current_frame += 1
            if animator.current_frame >= len(current_animation.frames) {
                if .LOOP in current_animation.flags {
                    animator.current_frame = 0
                } else {
                    animator.current_frame -= 1
                    animator.flags |= { .STOPPED }
                }
            }
        }
    }
}