
package main

import sdl "vendor:sdl2"
import "core:fmt"

Beetle :: struct {
  using shell : Entity_Shell,

  walk_dir   : Direction,
  anim_clock : int, 
}

update_beetle :: proc(beetle: ^Beetle) -> bool {
  using beetle
  position_prev = position

  if shell_clock != 0 {
    return update_shell(cast(^Entity_Shell)beetle)
  }

  anim_clock += 1
  if anim_clock >= GOOMBA_WALK_TIME do anim_clock = 0

  if walk_dir == .L {
    position.x -= GOOMBA_WALK_SPEED 
  } else if walk_dir == .R {
    position.x += GOOMBA_WALK_SPEED 
  }

  velocity.y = min(Plumber_Physics.max_fall_speed, velocity.y + Plumber_Physics.fall_gravity) 
  position += velocity

  if .DEAD not_in base.flags {
    // do tilemap collision
    {
      size, offset := get_beetle_collision_size_and_offset(beetle^)
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
          block_hit_entity(cast(^Entity)beetle, bump_dir)
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
      g_rect     := get_beetle_collision_rect(beetle^)
      g_rect.x   -= g_inst_vel.x
      g_rect.y   -= g_inst_vel.y
      
      collision, time, direction := swept_aabb_frect(p_rect, p_inst_vel, g_rect, g_inst_vel)
      if collision > 0 {
        if direction == .D {
          shell_clock = 60 * 5
          no_collide_player_clock = 20
          velocity = 0
          p.velocity.y = -Plumber_Physics.bounce_force
          add_bounce_score(p, position)
        }
      }
    }
  }

  if position.y > SCREEN_TILE_HEIGHT + 1 {
    return false
  }

  return true
}

beetle_animation_clips : [3] sdl.Rect = {
  {  0, 16, 16, 16 }, // walk 1
  { 16, 16, 16, 16 }, // walk 2
  { 32, 16, 16, 16 }, // shell
}

render_beetle :: proc(beetle: Beetle, tile_render_unit, offset: Vector2) {
  using GameState.active_level, beetle
  
  flip : sdl.RendererFlip
  clip, rect : sdl.Rect
  
  if shell_clock != 0 {
    render_shell(cast(Entity_Shell)beetle, tile_render_unit, offset)
    return
  }

  if .DEAD in beetle.base.flags {
    flip = .VERTICAL
    clip = beetle_animation_clips[2]
  } else {
    clip = beetle_animation_clips[int(anim_clock < GOOMBA_WALK_TIME / 2)]
    flip = walk_dir == .L ? .NONE : .HORIZONTAL
  }

  rect = {
    x = cast(i32) ((position.x - 0.5 + offset.x) * tile_render_unit.x),
    y = cast(i32) ((position.y - 0.5 + offset.y) * tile_render_unit.y),
    w = cast(i32) (tile_render_unit.x), 
    h = cast(i32) (tile_render_unit.y),
  }

  sdl.RenderCopyEx(renderer, entities_texture.sdl_texture, &clip, &rect, 0, nil, flip)
}

get_beetle_collision_rect :: proc(beetle: Beetle) -> sdl.FRect {
  using beetle
  size, offset := get_beetle_collision_size_and_offset(beetle)
  return {
    x = position.x + offset.x,
    y = position.y + offset.y,
    w = size.x,
    h = size.y,
  }  
}

get_beetle_collision_size_and_offset :: proc(using beetle: Beetle) -> (size, offset :Vector2) {
  size   = scale * Vector2 { 14.0 / 16.0, 11.0 / 16.0 }
  offset = -(size / 2) + {0, (1.0 / 16.0)}
  return
}

