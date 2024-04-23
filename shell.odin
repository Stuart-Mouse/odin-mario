
package main

import sdl "vendor:sdl2"
import "core:fmt"

Entity_Shell :: struct {
  using base  : Entity_Base,
  shell_clip  : sdl.Rect,
  shell_clock : i32,
  no_collide_player_clock : i32,
}

SHELL_KICK_SPEED :: 0.125

update_shell :: proc(using shell: ^Entity_Shell) -> bool {
  position_prev = position

  velocity.y = min(Plumber_Physics.max_fall_speed, velocity.y + Plumber_Physics.fall_gravity) 
  position += velocity

  if .DEAD not_in flags {
    // do tilemap collision
    on_ground := false
    {
      size, offset := get_shell_collision_size_and_offset(shell^)
      using collision_result := do_tilemap_collision(&GameState.active_level.tilemap, position, size, offset)
      position += position_adjust
      if .L in push_out {
        if velocity.x < 0 do velocity.x *= -1
      }
      if .R in push_out {
        if velocity.x > 0 do velocity.x *= -1
      }
      if .U in push_out {
        if velocity.y < 0 do velocity.y = Plumber_Physics.hit_ceiling
      }
      if .D in push_out {
        if velocity.y > 0 do velocity.y = 0
        on_ground = true
      }
      for dir in ([]Direction {.D, .DL, .DR}) {
        tile := indexed_tiles[dir]
        if tile != nil && tile_is_bumping(tile^) { // TODO: we should factor this into the collision results and just tell an entity that it's getting bumped
          bump_dir := dir
          if bump_dir == .D {
            if      velocity.y < 0 do bump_dir = .L
            else if velocity.y > 0 do bump_dir = .R
          }
          block_hit_entity(cast(^Entity)shell, bump_dir)
          break
        }
      }
    }

    if .MOVING not_in flags {
      // apply friction to slow the shell when moving, but not "moving".
      friction : f32 = on_ground ? 0.9 : 0.99
      velocity.x *= friction
    }

    // do collision with plumber
    player := &GameState.active_level.plumber
    player_collision_result    : int
    player_collision_direction : Direction

    no_collide_player_clock = max(no_collide_player_clock - 1, 0)
    if no_collide_player_clock == 0 {
      p_inst_vel := player.position - player.position_prev
      p_rect     := get_plumber_collision_rect(player^)
      p_rect.x   -= p_inst_vel.x
      p_rect.y   -= p_inst_vel.y

      s_inst_vel := position - position_prev
      s_rect     := get_shell_collision_rect(shell^)
      s_rect.x   -= s_inst_vel.x
      s_rect.y   -= s_inst_vel.y

      player_collision_result, _, player_collision_direction = swept_aabb_frect(p_rect, p_inst_vel, s_rect, s_inst_vel)
    }

    if .MOVING in flags {
      shell_clock = 60 * 5
      if player_collision_result > 0 {
        #partial switch player_collision_direction {
          case .D:
            flags &= ~{.MOVING}
            no_collide_player_clock = 20
            velocity = 0
            player.velocity.y = -Plumber_Physics.bounce_force
            add_bounce_score(player, position)
        }
      }
      for &slot in GameState.active_level.entities.slots {
        if slot.occupied && (uintptr(&slot.data) != uintptr(shell)) {
          s_rect := get_shell_collision_rect(shell^)
          e_rect := get_entity_collision_rect(slot.data)
          if aabb_frect(s_rect, e_rect) {
            shell_hit_entity(&slot.data)
          }
        }
      }
    } else {
      shell_clock = max(shell_clock - 1, 0)
      if player_collision_result > 0 {
        flags |= {.MOVING}
        no_collide_player_clock = 20
        
        player.score += 400
        spawn_score_particle(2, position)
        
        if GameState.active_level.plumber.position.x < shell.position.x {
          velocity.x = SHELL_KICK_SPEED
        } else {
          velocity.x = -SHELL_KICK_SPEED
        }
      }
    }
  }

  // check if the shell has fallen out of the level
  if position.y > SCREEN_TILE_HEIGHT + 1 {
    return false
  }

  return true
}

render_shell :: proc(shell: Entity_Shell, tile_render_unit, offset: Vector2) {
  using GameState.active_level, shell
  
  flip : sdl.RendererFlip
  clip, rect : sdl.Rect

  if .FLIPPED in flags {
    flip = .VERTICAL
  }

  clip = shell_clip
  rect = {
    x = cast(i32) ((position.x - 0.5 + offset.x) * tile_render_unit.x),
    y = cast(i32) ((position.y - 0.5 + offset.y) * tile_render_unit.y),
    w = cast(i32) (tile_render_unit.x), 
    h = cast(i32) (tile_render_unit.y),
  }

  sdl.RenderCopyEx(renderer, entities_texture.sdl_texture, &clip, &rect, 0, nil, flip)
}

get_shell_collision_rect :: proc(shell: Entity_Shell) -> sdl.FRect {
  using shell
  size, offset := get_shell_collision_size_and_offset(shell)
  return {
    x = position.x + offset.x,
    y = position.y + offset.y,
    w = size.x,
    h = size.y,
  }  
}

get_shell_collision_size_and_offset :: proc(using shell: Entity_Shell) -> (size, offset :Vector2) {
  size   = scale * Vector2 { 14.0 / 16.0, 11.0 / 16.0 }
  offset = -(size / 2) + {0, (1.0 / 16.0)}
  return
}