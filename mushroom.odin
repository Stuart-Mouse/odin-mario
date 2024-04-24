package main

import sdl "vendor:sdl2"
import "core:fmt"

Mushroom :: struct {
  using base : Entity_Base,
  walk_dir   : Direction,
}

Mushroom_Type :: enum {
  SUPER,
  ONE_UP,
}

render_mushroom :: proc(mushroom: Mushroom, tile_render_unit, offset: Vector2) {
  using GameState.active_level, mushroom
  
  flip : sdl.RendererFlip
  clip, rect : sdl.Rect
  
  clip = { 32, 0, 16, 16 }
  rect = {
    x = cast(i32) ((position.x - 0.5 + offset.x) * tile_render_unit.x),
    y = cast(i32) ((position.y - 0.5 + offset.y) * tile_render_unit.y),
    w = cast(i32) (tile_render_unit.x), 
    h = cast(i32) (tile_render_unit.y),
  }

  sdl.RenderCopyEx(renderer, entities_texture.sdl_texture, &clip, &rect, 0, nil, flip)
}

update_mushroom :: proc(mushroom: ^Mushroom) -> bool {
  using mushroom
  position_prev = position

  if walk_dir == .L {
    position.x -= GOOMBA_WALK_SPEED 
  } else if walk_dir == .R {
    position.x += GOOMBA_WALK_SPEED 
  }

  velocity.y = min(Plumber_Physics.max_fall_speed, velocity.y + Plumber_Physics.fall_gravity) 
  position += velocity

  // do tilemap collision
  {
    size, offset := get_mushroom_collision_size_and_offset(mushroom^)
    using collision_result := do_tilemap_collision(&GameState.active_level.tilemap, position, size, offset)
    position += position_adjust
    if .L in push_out {
      if walk_dir == .L do walk_dir = .R
      if velocity.x < 0 do velocity.x = 0
    }
    if .R in push_out {
      if walk_dir == .R do walk_dir = .L
      if velocity.x > 0 do velocity.x = 0
    }
    if .U in push_out {
      if velocity.y < 0 do velocity.y = Plumber_Physics.hit_ceiling
    }
    if .D in push_out {
      if velocity.y > 0 do velocity.y = 0
    }
    for dir in ([]Direction {.D, .DL, .DR}) {
      tile := indexed_tiles[dir]
      if tile != nil && tile.bump_clock > 0 {
        bump_dir := dir
        if bump_dir == .D {
          bump_dir = walk_dir
        }
        block_hit_entity(cast(^Entity)mushroom, bump_dir)
        break
      }
    }
  }

  // do collision with plumber
  {
    p      := &GameState.active_level.plumber
    p_rect := get_plumber_collision_rect(p^)
    m_rect := get_mushroom_collision_rect(mushroom^)

    if aabb_frect(p_rect, m_rect) {
      if p.powerup < Powerup.SUPER {
        change_player_powerup_state(p, Powerup.SUPER)
      }
      return false
    }
  }

  // check if the mushroom has fallen out of the level
  if position.y > SCREEN_TILE_HEIGHT + 1 {
    return false
  }

  return true
}

get_mushroom_collision_rect :: proc(mushroom: Mushroom) -> sdl.FRect {
  using mushroom
  size, offset := get_mushroom_collision_size_and_offset(mushroom)
  return {
    x = position.x + offset.x,
    y = position.y + offset.y,
    w = size.x,
    h = size.y,
  }  
}

get_mushroom_collision_size_and_offset :: proc(using mushroom: Mushroom) -> (size, offset :Vector2) {
  size   = scale * Vector2 { 14.0 / 16.0, 11.0 / 16.0 }
  offset = -(size / 2) + {0, (1.0 / 16.0)}
  return
}
