package main

import "core:math"
import "core:fmt"
// import "core:rand"
import sdl "vendor:sdl2"

plumber_texture : Texture

Plumber_Physics : struct {
  jump_gravity        : f32,
  fall_gravity        : f32,
  jump_force          : f32,
  jump_height         : f32,
  run_jump_height     : f32,
  run_jump_force      : f32,
  jump_release_height : f32,
  jump_release_force  : f32,
  bounce_height       : f32,
  bounce_force        : f32,
  walk_accel          : f32,
  run_accel           : f32,
  walk_speed          : f32,
  run_speed           : f32,
  skid_decel          : f32,
  release_decel       : f32,
  hit_ceiling         : f32,
  max_fall_speed      : f32,
  air_accel           : f32,
  air_decel           : f32,
  coyote_time         : f32,
  coyote_frames       : i32,
}

init_plumber_physics :: proc() {
  using Plumber_Physics
  jump_gravity        = 0.009
  fall_gravity        = 0.016
  jump_height         = 4.25
  run_jump_height     = 5.5
  jump_release_height = 0.5
  walk_accel          = 0.001
  run_accel           = 0.002
  walk_speed          = 0.05
  run_speed           = 0.145
  skid_decel          = 0.004
  release_decel       = 0.002
  hit_ceiling         = 0.1
  max_fall_speed      = 0.3
  air_accel           = 0.0025
  air_decel           = 0.0001
  coyote_time         = 0.1
  bounce_height       = 1.0
  calc_plumber_physics()
}

calc_plumber_physics :: proc() {
  using Plumber_Physics
  jump_force         = math.sqrt(2.0 * jump_gravity * jump_height)
  run_jump_force     = math.sqrt(2.0 * jump_gravity * run_jump_height)
  jump_release_force = math.sqrt(2.0 * jump_gravity * jump_release_height)
  bounce_force       = math.sqrt(2.0 * jump_gravity * bounce_height)
  coyote_frames      = i32(coyote_time * 60.0)
}

show_plumber_collision_points : bool

Powerup :: enum {
  NONE,
  SUPER,
  FIRE,
}

Plumber_Input_Keys :: enum {
  DOWN, 
  LEFT,
  RIGHT,
  RUN,
  JUMP,
  POWERUP,
  POWERDOWN,
  COUNT,
}

Plumber :: struct {
  position_prev : Vector2,
  position      : Vector2,
  velocity      : Vector2,
  scale         : Vector2,
  controller    : [Plumber_Input_Keys.COUNT] InputKey,
  powerup       : Powerup,
  coins         : int,
  score         : int,
  seq_bounces   : int,
  lives         : int,

  anim_state    : Plumber_Animation_States,
  anim_frame    : f32,
  flags         : Plumber_Flags,

  coyote_clock  : i32,

  collision_results : Tilemap_Collision_Results,
}

Plumber_Flags :: bit_set[Plumber_Flag]
Plumber_Flag :: enum {
  ON_GROUND,
  FACING_LEFT,
  CROUCHING,
}

init_plumber_controller :: proc(using plumber: ^Plumber) {
  using Plumber_Input_Keys
  controller[DOWN ] = { sc = .DOWN  }
  controller[LEFT ] = { sc = .LEFT  }
  controller[RIGHT] = { sc = .RIGHT }
  controller[RUN  ] = { sc = .Z     }
  controller[JUMP ] = { sc = .X     }

  controller[POWERUP  ] = { sc = .W     }
  controller[POWERDOWN] = { sc = .Q     }
}

update_plumber :: proc(using plumber: ^Plumber) {
  using Plumber_Input_Keys
  using Plumber_Physics

  update_input_controller(controller[:])

  if controller[POWERDOWN].state == KEYSTATE_PRESSED {
    powerup = max(powerup - Powerup(1), Powerup.NONE)
  }
  if controller[POWERUP].state == KEYSTATE_PRESSED {
    powerup = min(powerup + Powerup(1), Powerup.FIRE)
  }

  position_prev = position

  // do player physics
  can_jump := false
  gravity  := fall_gravity
  
  coyote_clock += 1

  if .ON_GROUND in flags {
    can_jump     = true
    coyote_clock = 0

    move_accel := walk_accel
    move_speed := walk_speed
    decel          := release_decel // amount of deceleration to apply
    decel_to_speed := walk_speed    // what speed to decelerate the player towards
    if bool(controller[RUN].state & KEYSTATE_PRESSED) {
      move_accel = run_accel
      move_speed = run_speed
      decel_to_speed = run_speed
    }

    // if the player is crouching, then they cannot apply any acceleration
    if powerup != .NONE && bool(controller[DOWN].state & KEYSTATE_PRESSED) {
      flags |=  { .CROUCHING }
      if bool(controller[RIGHT].state & KEYSTATE_PRESSED) {
        flags &= ~{.FACING_LEFT}
      }
      else if bool(controller[LEFT].state & KEYSTATE_PRESSED) {
        flags |= {.FACING_LEFT}
      }
      decel_to_speed = 0
    } else {
      flags &= ~{ .CROUCHING }
      if bool(controller[RIGHT].state & KEYSTATE_PRESSED) {
        flags &= ~{.FACING_LEFT}
        if velocity.x >= 0 {
          applicable_accel := max(0, move_speed - velocity.x)
          velocity.x += min(move_accel, applicable_accel)
        } else {
          velocity.x += skid_decel
        }
      }
      else if bool(controller[LEFT].state & KEYSTATE_PRESSED) {
        flags |= {.FACING_LEFT}
        if velocity.x <= 0 {
          applicable_accel := max(0, move_speed + velocity.x)
          velocity.x -= min(move_accel, applicable_accel)
        } else {
          velocity.x -= skid_decel
        }
      }
      else { // neither direction pressed
        decel = (.FACING_LEFT in flags) != (velocity.x < 0) ?\
          skid_decel : release_decel
        decel_to_speed = 0
      }
    }

    apply_decel : f32
    if      velocity.x >  decel_to_speed do apply_decel = -min(velocity.x - decel_to_speed, decel)
    else if velocity.x < -decel_to_speed do apply_decel =  min(decel_to_speed - velocity.x, decel)
    velocity.x += apply_decel
  }
  else {
    if velocity.y < 0 do gravity = jump_gravity
    if coyote_clock < coyote_frames do can_jump = true

    move_accel := air_accel
    move_speed := walk_speed
    if bool(controller[RUN].state & KEYSTATE_PRESSED) {
      move_speed = run_speed
    }
    if bool(controller[JUMP].state == KEYSTATE_RELEASED) {
      if velocity.y < -jump_release_force {
        velocity.y = -jump_release_force
      }
    }

    if bool(controller[RIGHT].state & KEYSTATE_PRESSED) {
      applicable_accel := max(0, move_speed - velocity.x)
      velocity.x += min(move_accel, applicable_accel)
    }
    else if bool(controller[LEFT].state & KEYSTATE_PRESSED) {
      applicable_accel := max(0, move_speed + velocity.x)
      velocity.x -= min(move_accel, applicable_accel)
    }
    else { // neither direction pressed
      decel := air_decel
      if      velocity.x >  decel do velocity.x -= decel
      else if velocity.x < -decel do velocity.x += decel
      else                        do velocity.x  = 0
    }
  }

  velocity.y += gravity
  if controller[JUMP].state == KEYSTATE_PRESSED && can_jump {
    jump_percent     := clamp(delerp(walk_speed, run_speed, abs(velocity.x)), 0, 1)
    apply_jump_force := lerp(jump_force, run_jump_force, jump_percent)
    velocity.y = -apply_jump_force
  }
  
  velocity.y = min(velocity.y, max_fall_speed)

  position += velocity
    
  if powerup == .FIRE && .CROUCHING not_in flags && bool(controller[RUN].state == KEYSTATE_PRESSED) {
    slot := get_next_empty_slot(&GameState.active_level.entities)
    if slot != nil {
      slot.occupied = true
      init_entity(&slot.data, .FIREBALL)
      
      facing_mul : f32 = .FACING_LEFT in flags ? -1 : 1
      slot.data.base.position = plumber.position + Vector2 { 0.5 * facing_mul, 0 }
      slot.data.base.velocity = Vector2 { 0.2 * facing_mul, 0.1 }
    }
  }

  flags &= ~{ .ON_GROUND }
  size, offset := get_plumber_collision_size_and_offset(plumber^)

  // keep player on the screen
  {
    camera := &GameState.active_level.camera

    left_side   := position.x  + offset.x
    right_side  := left_side   + size.x

    if left_side < camera.x {
      position.x = camera.x - offset.x
      if velocity.y < 0 do velocity.x = 0
    }
    if right_side > camera.x + SCREEN_TILE_WIDTH - 1 {
      position.x = camera.x + SCREEN_TILE_WIDTH - 1 + offset.x
      if velocity.y > 0 do velocity.x = 0
    }
    if position.y > SCREEN_TILE_HEIGHT + 1 {
      position.y -= (SCREEN_TILE_HEIGHT + 1)
    }
  }

  // do tilemap collision
  {
    using collision_results
    collision_results = do_tilemap_collision(&GameState.active_level.tilemap, position, size, offset)
    position += position_adjust
    
    // collect coins
    for &tile in indexed_tiles {
        if tile == nil do continue
        if get_tile_collision(tile^).type == .COIN {
            coins += 1
            if coins == 100 {
                lives += 1
                coins = 0
            }
            tile^ = {}
        }
    }
    
    // bump/break tiles the player hits with their head
    for dir in ([]Direction{ .U, .UL, .UR }) {
      tile := indexed_tiles[dir]
      if tile == nil            do continue
      if resolutions[dir] != .U do continue
      if velocity.y > 0         do continue

      ti := get_tile_info(tile^)
      if ti == nil do continue
      if .BUMPABLE in ti.collision.flags {
        if tile.bump_clock == 0 {
          tile.bump_clock = TILE_BUMP_TIME

          if .BREAKABLE in ti.collision.flags {
            if powerup > .NONE {
              tile.flags |= { .BROKEN }
              index := Vector2 { f32(indices[dir].x), f32(indices[dir].y) }
              create_block_break_particles(
                tile      = tile^,
                position  = index,
                pieces    = { 2, 2 },
                vel_x     = { -0.07,  0.07 },
                vel_y     = { -0.35, -0.30 },
                vel_ax    = { -7   ,  7    },
                vel_var   = {  0.05,  0.05,  3 },
                vel_extra = velocity * { 0.5, 0 },
              )
            }
          }
          if .CONTAINER in ti.collision.flags  {
            if tile.bump_clock == 0 do tile.bump_clock = TILE_BUMP_TIME
          }
        }
      }
    }
    if .U in push_out {
      if velocity.y < 0 do velocity.y = hit_ceiling
    }
    if .D in push_out {
      if velocity.y > 0 do velocity.y = 0
      flags |= { .ON_GROUND }
    }
    if .L in push_out {
      if velocity.x < 0 do velocity.x = 0
    }
    if .R in push_out {
      if velocity.x > 0 do velocity.x = 0
    }
  }
  
  if .ON_GROUND in flags {
    seq_bounces = 0
  }


  // update camera
  {
    using GameState.active_level

    right_cam_point := camera.x + 0.5 * SCREEN_TILE_WIDTH
    if position.x > right_cam_point {
      camera.x += position.x - right_cam_point
      camera.x = min(camera.x, LEVEL_TILE_WIDTH - SCREEN_TILE_WIDTH)
    }

    left_cam_point := camera.x + 0.4 * SCREEN_TILE_WIDTH
    if position.x < left_cam_point {
      camera.x += position.x - left_cam_point
      camera.x = max(camera.x, 0)
    }
  }

  // determine animation state 
  {
    anim_state_prev := anim_state

    if powerup != .NONE && .CROUCHING in flags {
      anim_state = .CROUCH
    }
    else if .ON_GROUND not_in flags {
      anim_state = .JUMP
    } else {
      if abs(velocity.x) < 0.01 {
        anim_state = .STAND
      }
      else {
        if (.FACING_LEFT in flags) != (velocity.x < 0) {
          anim_state = .SKID
        } else {
          anim_state = .WALK
        }
      }
    }

    // ensures that if state changes, we won't try to index an invalid animation clip
    if anim_state != anim_state_prev {
      anim_frame = 0
    } else {
      // if animation state is the same, then we want to perform some animation within the state
      // since we may want to animate through clips defferently depending on the animation state, we switch on the state
      if anim_state == .WALK {
        anim_frame += abs(velocity.x) * 4
        if anim_frame >= cast(f32) len(Plumber_Animation_Clips[powerup][anim_state]) {
          anim_frame = 0
        }
      }
    }
  }
}

Plumber_Animation_States :: enum {
  STAND, 
  WALK,
  SKID,
  JUMP,
  CROUCH,
  DEAD,
}

Plumber_Animation_Clips : [Powerup][Plumber_Animation_States][] sdl.Rect = {
  .NONE = {
    .STAND = {
      {  0, 0, 16, 16 },
    },
    .WALK = {
      { 16, 0, 16, 16 },
      { 32, 0, 16, 16 },
      { 48, 0, 16, 16 },
    },
    .SKID = {
      { 64, 0, 16, 16 },
    },
    .JUMP = {
      { 80, 0, 16, 16 },
    },
    .DEAD = {
      { 96, 0, 16, 16 },
    },
    .CROUCH = {},
  },
  .SUPER = {
    .STAND = {
      {  0, 16, 16, 32 },
    },
    .WALK = {
      { 16, 16, 16, 32 },
      { 32, 16, 16, 32 },
      { 48, 16, 16, 32 },
    },
    .SKID = {
      { 64, 16, 16, 32 },
    },
    .JUMP = {
      { 80, 16, 16, 32 },
    },
    .CROUCH = {
      { 96, 16, 16, 32 },
    },
    .DEAD = {},
  },
  .FIRE = {
    .STAND = {
      {  0, 48, 16, 32 },
    },
    .WALK = {
      { 16, 48, 16, 32 },
      { 32, 48, 16, 32 },
      { 48, 48, 16, 32 },
    },
    .SKID = {
      { 64, 48, 16, 32 },
    },
    .JUMP = {
      { 80, 48, 16, 32 },
    },
    .CROUCH = {
      { 96, 48, 16, 32 },
    },
    .DEAD = {},
  },
}

render_plumber :: proc(using plumber: ^Plumber, tile_render_unit, offset: Vector2) {
  camera := &GameState.active_level.camera

  size : Vector2 
  switch powerup {
    case .NONE:
      size = { 1, 1 }
    case .FIRE:
      fallthrough
    case .SUPER:
      size = { 1, 2 }
  }

  self_offset     := -(scale * size) / 2
  render_position := (position + offset + self_offset) * tile_render_unit
  render_size     := scale * size * tile_render_unit

  clip := Plumber_Animation_Clips[powerup][anim_state][cast(int) anim_frame]
  rect := sdl.Rect {
    x = cast(i32) render_position.x,
    y = cast(i32) render_position.y,
    w = cast(i32) render_size.x, 
    h = cast(i32) render_size.y,
  }
  
  flip : sdl.RendererFlip = .FACING_LEFT in flags ? .HORIZONTAL : .NONE
  sdl.RenderCopyEx(renderer, plumber_texture.sdl_texture, &clip, &rect, 0, nil, flip)

  // debug render collision points
  if show_plumber_collision_points {
    for dir in Direction(0)..<Direction(8) {
      if dir in collision_results.push_out {
        sdl.SetRenderDrawColor(renderer, 0xff, 0x00, 0x00, 0xff)
      } else {
        sdl.SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff)
      }
      render_position := (collision_results.points[dir] + offset) * tile_render_unit - 1.0
      rect := sdl.Rect {
        x = i32(render_position.x),
        y = i32(render_position.y),
        w = 3, 
        h = 3,
      }
      sdl.RenderDrawRect(renderer, &rect)
    }
  }
}

get_plumber_collision_rect :: proc(using plumber: Plumber) -> sdl.FRect {
  size, offset := get_plumber_collision_size_and_offset(plumber)
  return {
    x = position.x + offset.x,
    y = position.y + offset.y,
    w = size.x,
    h = size.y,
  }
}

get_plumber_collision_size_and_offset :: proc(using plumber: Plumber) -> (size, offset :Vector2) {
  switch powerup {
    case .NONE:
      size   = scale * Vector2 { 14.0 / 16.0, 14.0 / 16.0 }
      offset = -size / 2
    case .FIRE: fallthrough
    case .SUPER:
      if .CROUCHING in flags {
        size   = scale * Vector2 { 14.0 / 16.0, 14.0 / 16.0 }
        offset = -size / 2
        offset.y += 0.5
      } else {
        size   = scale * Vector2 { 14.0 / 16.0, 30.0 / 16.0 }
        offset = -size / 2
      }
  }
  return
}

add_bounce_score :: proc(using plumber: ^Plumber, spawn_position: Vector2) {
    bounce_scores := []int {
        100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000
    }
    
    if seq_bounces < 0 do seq_bounces = 0
    if seq_bounces >= len(bounce_scores) {
        plumber.lives += 1
    } else {
        plumber.score += bounce_scores[plumber.seq_bounces]
    }
    
    spawn_score_particle(seq_bounces, spawn_position)
    
    seq_bounces = min(seq_bounces + 1, len(bounce_scores))
}

spawn_score_particle :: proc(score_index: int, spawn_position: Vector2) {    
    score_particles_clips := []sdl.Rect {
        {  0, 24, 16,  8 }, // 100
        {  0, 32, 16,  8 }, // 200
        {  0, 40, 16,  8 }, // 400
        {  0, 48, 16,  8 }, // 500
        {  0, 56, 16,  8 }, // 800
        
        { 16, 24, 16,  8 }, // 1000
        { 16, 32, 16,  8 }, // 2000
        { 16, 40, 16,  8 }, // 4000
        { 16, 48, 16,  8 }, // 5000
        { 16, 56, 16,  8 }, // 8000
        { 16, 64, 16,  8 }, // 1-UP
    }
    
    if score_index < 0 || score_index >= len(score_particles_clips) do return
    
    using GameState.active_level
    slot := get_next_slot(&particles[0])
    slot.occupied = true
    slot.data = {
        velocity  = { 0, -0.03 },
        position  = spawn_position,
        scale     = { 1, 1 },
        texture   = decor_texture.sdl_texture,
        animation = {
            frame_count = 2,
            frames = {
                {
                    clip = score_particles_clips[score_index],
                    duration = 30,
                },
                {}, {}, {}, {}, {}, {}, {},
            },
        },
    }
}