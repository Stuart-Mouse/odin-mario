package main

import sdl "vendor:sdl2"
import "core:fmt"

Goomba :: struct {
  using base : Entity_Base,
  walk_dir   : Direction,
  anim_clock : int, 
}

goomba_animation_clips : [2] sdl.Rect = {
  {  0,  0, 16, 16 }, // walk
  { 16,  0, 16, 16 }, // dead
}

render_goomba :: proc(goomba: Goomba, tile_render_unit, offset: Vector2) {
  using GameState.active_level, goomba
  
  flip : sdl.RendererFlip
  clip, rect : sdl.Rect
  
  if .CRUSHED in goomba.flags {
    clip = goomba_animation_clips[1]
  } else {
    clip = goomba_animation_clips[0]
    if .DEAD in goomba.flags {
      flip = .VERTICAL
    } else {
      flip = anim_clock < GOOMBA_WALK_TIME / 2 ? .NONE : .HORIZONTAL
    }
  }

  rect = {
    x = cast(i32) ((position.x - 0.5 + offset.x) * tile_render_unit.x),
    y = cast(i32) ((position.y - 0.5 + offset.y) * tile_render_unit.y),
    w = cast(i32) (tile_render_unit.x), 
    h = cast(i32) (tile_render_unit.y),
  }

  sdl.RenderCopyEx(renderer, entities_texture.sdl_texture, &clip, &rect, 0, nil, flip)
}

GOOMBA_DEAD_TIME  :: 30
GOOMBA_WALK_TIME  :: 20

GOOMBA_WALK_SPEED : f32 = 0.025

update_goomba :: proc(goomba: ^Goomba) -> bool {
  using goomba
  position_prev = position

  anim_clock += 1
  if .CRUSHED in flags {
    if anim_clock >= GOOMBA_DEAD_TIME {
      return false
    }
    return true
  }
  if anim_clock >= GOOMBA_WALK_TIME do anim_clock = 0

  if walk_dir == .L {
    position.x -= GOOMBA_WALK_SPEED 
  } else if walk_dir == .R {
    position.x += GOOMBA_WALK_SPEED 
  }

  // apply gravity to the goomba
  velocity.y = min(Plumber_Physics.max_fall_speed, velocity.y + Plumber_Physics.fall_gravity) 

  // apply the velocity to the position
  position += velocity

  // if the goomba is dead, it will not collide with anything anymore, but we will wait for it to fall off the screen before actually destroying it
  if .DEAD not_in flags {
    // do tilemap collision
    {
      size, offset := get_goomba_collision_size_and_offset(goomba^)
      using collision_result := do_tilemap_collision(&GameState.active_level.tilemap, position, size, offset)
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
      }
      for dir in ([]Direction {.D, .DL, .DR}) {
        tile := indexed_tiles[dir]
        if tile != nil && tile_is_bumping(tile^) {
          bump_dir := dir
          if bump_dir == .D {
            bump_dir = walk_dir
          }
          block_hit_entity(cast(^Entity)goomba, bump_dir)
          break
        }
      }
    }

    // do collision with plumber
    {
      p          := &GameState.active_level.plumber
      p_inst_vel := p.position - p.position_prev
      p_rect     := get_plumber_collision_rect(p^)
      p_rect.x   -= p_inst_vel.x
      p_rect.y   -= p_inst_vel.y

      g_inst_vel := position - position_prev
      g_rect     := get_goomba_collision_rect(goomba^)
      g_rect.x   -= g_inst_vel.x
      g_rect.y   -= g_inst_vel.y
      
      collision, time, direction := swept_aabb_frect(p_rect, p_inst_vel, g_rect, g_inst_vel)
      if collision > 0 {
        if direction == .D {
          flags |= {.CRUSHED}
          anim_clock = 0
          p.velocity.y = -Plumber_Physics.bounce_force
          add_bounce_score(p, position)
        } else {
          change_player_powerup_state(p, p.powerup - Powerup(1))
        }
      }
    }
  }

  // check if the goomba has fallen out of the level
  if position.y > SCREEN_TILE_HEIGHT + 1 {
    return false
  }

  return true
}

get_goomba_collision_rect :: proc(goomba: Goomba) -> sdl.FRect {
  using goomba
  size, offset := get_goomba_collision_size_and_offset(goomba)
  return {
    x = position.x + offset.x,
    y = position.y + offset.y,
    w = size.x,
    h = size.y,
  }  
}

get_goomba_collision_size_and_offset :: proc(using goomba: Goomba) -> (size, offset :Vector2) {
  size   = scale * Vector2 { 14.0 / 16.0, 11.0 / 16.0 }
  offset = -(size / 2) + {0, (1.0 / 16.0)}
  return
}
