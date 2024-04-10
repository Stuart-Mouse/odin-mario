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
  clip             : sdl.Rect,
  texture          : ^sdl.Texture,
}

update_particle :: proc(using particle: ^Particle) -> bool {
  velocity += acceleration
  position += velocity
  rotation += angular_velocity

  using GameState.active_level
  if position.y > SCREEN_TILE_HEIGHT + 3 || position.y < -3 ||
     position.x > LEVEL_TILE_WIDTH  + 3 || position.x < -3 {
    return false
  }
  return true
}

render_particle :: proc(using particle: ^Particle, tile_render_unit, offset: Vector2) {
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
    &clip, &rect, 
    f64(rotation), nil,
    .NONE,
  )
}
