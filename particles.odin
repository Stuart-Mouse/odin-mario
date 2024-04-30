package main

import sdl "vendor:sdl2"
import "core:fmt"

decor_texture : Texture

Particle :: struct {
  position         : Vector2,
  velocity         : Vector2,
  acceleration     : Vector2,
  scale            : Vector2,
  rotation         : f32,
  angular_velocity : f32,

  texture : ^sdl.Texture,
  animation : struct { 
    frames  : [MAX_TILE_ANIM_FRAMES] struct {
      clip        : sdl.Rect,
      duration    : int,
    },
    frame_count   : int,
    current_frame : int,
    frame_clock   : int,
    loop          : int,
  },
}

update_particle :: proc(using particle: ^Particle) -> bool {
  velocity += acceleration
  position += velocity
  rotation += angular_velocity

  if position.y > SCREEN_TILE_HEIGHT + 3 || position.y < -3 ||
     position.x > LEVEL_TILE_WIDTH   + 3 || position.x < -3 {
    return false
  }

  using animation
  if frame_count > 1 {
    frame_clock += 1
    if frame_clock >= frames[current_frame].duration {
      current_frame += 1
      frame_clock = 0
      if current_frame >= frame_count {
        loop -= 1
        if loop == -1 do return false
        current_frame  = 0
      }
    }
  }

  return true
}

render_particle :: proc(using particle: ^Particle, tile_render_unit, offset: Vector2) {
  using animation
  clip            := &frames[current_frame].clip
  clip_size       := Vector2 { f32(clip.w), f32(clip.h) }
  render_size     := (clip_size * scale) * tile_render_unit / TILE_TEXTURE_SIZE 
  render_position := ((position + offset) * tile_render_unit) - (render_size / 2)

  rect := sdl.Rect {
    x = i32(render_position.x),
    y = i32(render_position.y),
    w = i32(render_size.x),
    h = i32(render_size.y),
  }
  
  sdl.RenderCopyEx(
    renderer, 
    texture, 
    clip, &rect, 
    f64(rotation), nil,
    .NONE,
  )
}


