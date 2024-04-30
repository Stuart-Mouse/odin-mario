
package main

import sdl "vendor:sdl2"
import "core:fmt"
import "core:math"

Koopa :: struct {
  using shell : Entity_Shell,

  walk_dir   : Direction,
  anim_clock : int, 
}

update_koopa :: proc(koopa: ^Koopa) -> bool {
    using koopa
    position_prev = position

    if shell_clock != 0 {
        return update_shell(cast(^Entity_Shell)koopa)
    }

    anim_clock += 1
    if anim_clock >= GOOMBA_WALK_TIME do anim_clock = 0

    if walk_dir == .L {
        position.x -= GOOMBA_WALK_SPEED 
    } else if walk_dir == .R {
        position.x += GOOMBA_WALK_SPEED 
    }

    applied_gravity := Plumber_Physics.fall_gravity
    if .WINGED in flags {
        WINGED_KOOPA_JUMP_FORCE :: 0.2
        if .ON_GROUND in flags {
            velocity.y -= WINGED_KOOPA_JUMP_FORCE
        }
        applied_gravity /= 2
    }

    friction : f32 = .ON_GROUND in flags ? 0.9 : 1
    velocity.x *= friction

    velocity.y = min(Plumber_Physics.max_fall_speed, velocity.y + applied_gravity) 
    position += velocity

    if .DEAD not_in flags {
        flags &= ~{.ON_GROUND}
        
        // do tilemap collision
        {
            tilemap := &GameState.active_level.tilemap
            size, offset := get_koopa_collision_size_and_offset(koopa^)
            using collision_result := do_tilemap_collision(tilemap, position, size, offset)
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
                flags |= {.ON_GROUND}
                if velocity.y > 0 do velocity.y = 0
              
                // handle turning around at ledges
                if .DONT_WALK_OFF_LEDGES in flags {
                    x_frac := (position.x - math.floor(position.x))
                    if .DL not_in push_out && walk_dir == .L && x_frac < 0.25 do walk_dir = .R
                    if .DR not_in push_out && walk_dir == .R && x_frac > 0.75 do walk_dir = .L
                }
            }
            for dir in ([]Direction {.D, .DL, .DR}) {
                tile := get_tile(tilemap, indexed_tiles[dir])
                if tile != nil && tile_is_bumping(tile^) {
                    bump_dir := dir
                    if bump_dir == .D {
                        bump_dir = walk_dir
                    }
                    block_hit_entity(cast(^Entity)koopa, bump_dir)
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
            g_rect     := get_koopa_collision_rect(koopa^)
            g_rect.x   -= g_inst_vel.x
            g_rect.y   -= g_inst_vel.y
            
            collision, time, direction := swept_aabb_frect(p_rect, p_inst_vel, g_rect, g_inst_vel)
            if collision > 0 {
                if direction == .D {
                    if .WINGED in flags {
                        flags &= ~{.WINGED}
                    } else {
                        shell_clock = 60 * 5
                        no_collide_player_clock = 20
                    }
                    velocity = 0
                    p.velocity.y = -Plumber_Physics.bounce_force
                    add_bounce_score(p, position)
                } else {
                    plumber_take_damage(p)
                }
            }
        }
    }

    if position.y > SCREEN_TILE_HEIGHT + 1 {
        return false
    }

    return true
}

koopa_animation_clips : [3] sdl.Rect = {
  {  0, 32, 16, 24 }, // walk 1
  { 16, 32, 16, 24 }, // walk 2
  { 64, 40, 16, 16 }, // shell
}

render_koopa :: proc(koopa: Koopa, tile_render_unit, offset: Vector2) {
  using GameState.active_level, koopa
  
  flip : sdl.RendererFlip
  clip, rect : sdl.Rect
  
  if shell_clock != 0 {
    render_shell(cast(Entity_Shell)koopa, tile_render_unit, offset)
    return
  }

  if .DEAD in flags {
    flip = .VERTICAL
    clip = koopa_animation_clips[2]
  } else {
    clip = koopa_animation_clips[int(anim_clock < GOOMBA_WALK_TIME / 2)]
    flip = walk_dir == .L ? .NONE : .HORIZONTAL
    if .WINGED in flags do clip.x += 32
  }
  
  if .DONT_WALK_OFF_LEDGES in koopa.flags {
    clip.y += 24
  }

  rect = {
    x = cast(i32) ((position.x - 0.5 + offset.x) * tile_render_unit.x),
    y = cast(i32) ((position.y - 1.0 + offset.y) * tile_render_unit.y),
    w = cast(i32) (tile_render_unit.x), 
    h = cast(i32) (tile_render_unit.y * 1.5),
  }

  sdl.RenderCopyEx(renderer, entities_texture.sdl_texture, &clip, &rect, 0, nil, flip)
}

get_koopa_collision_rect :: proc(koopa: Koopa) -> sdl.FRect {
  using koopa
  size, offset := get_koopa_collision_size_and_offset(koopa)
  return {
    x = position.x + offset.x,
    y = position.y + offset.y,
    w = size.x,
    h = size.y,
  }
}

get_koopa_collision_size_and_offset :: proc(using koopa: Koopa) -> (size, offset :Vector2) {
  size   = scale * Vector2 { 14.0 / 16.0, 11.0 / 16.0 }
  offset = -(size / 2) + {0, (1.0 / 16.0)}
  return
}

