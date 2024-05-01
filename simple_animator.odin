
package main

import sdl "vendor:sdl2"
import "core:fmt"

Simple_Animator :: struct(Anim_Enum: typeid) {
    state         : Anim_Enum,
    current_frame : int,
    frame_clock   : int,
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