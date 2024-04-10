package main

import sdl "vendor:sdl2"
import "core:fmt"

entities_texture : Texture

Entity_Base :: struct {
  tag           : Entity_Type,
  position_prev : Vector2, 
  position      : Vector2, 
  velocity      : Vector2, 
  scale         : Vector2, 
  on_ground     : bool,
}

Entity_Type :: enum {
  NONE,
  GOOMBA,
  MUSHROOM,
  SHELL,
}

Entity :: struct #raw_union {
  base     : Entity_Base,
  goomba   : Goomba,
  mushroom : Mushroom,
  shell    : Entity_Shell,
}

Goomba :: struct {
  using base : Entity_Base,
  walk_dir   : Direction,
  is_dead    : bool, 
  anim_clock : int, 
}

Mushroom :: struct {
  using base : Entity_Base,
  walk_dir   : Direction,
}

goomba_animation_clips : [2] sdl.Rect = {
  {  0,  0, 16, 16 }, // walk
  { 16,  0, 16, 16 }, // dead
}

init_entity :: proc(entity: ^Entity, type: Entity_Type) {
  if entity == nil do return 
  #partial switch type {
    case .GOOMBA:
      entity.goomba = {
        scale = { 1, 1 },
        walk_dir = .L,
      }
    case .MUSHROOM:
      entity.mushroom = {
        scale = { 1, 1 },
        walk_dir = .R,
      }
    case .SHELL:
      entity.shell = {
        scale = { 1, 1 },
      }
    case:
      assert(false)
  }
  entity.base.tag = type
}

render_entity :: proc(using entity: Entity, tile_render_unit, offset: Vector2) {
  clip, rect : sdl.Rect
  flip : sdl.RendererFlip

  #partial switch base.tag {
    case .GOOMBA   : render_goomba  (goomba  , tile_render_unit, offset)
    case .MUSHROOM : render_mushroom(mushroom, tile_render_unit, offset)
    case .SHELL    : render_shell   (shell   , tile_render_unit, offset)
  }
}

render_goomba :: proc(goomba: Goomba, tile_render_unit, offset: Vector2) {
  using GameState.active_level, goomba
  
  flip : sdl.RendererFlip
  clip, rect : sdl.Rect
  
  if is_dead {
    clip = goomba_animation_clips[1]
  } else {
    flip = anim_clock < GOOMBA_WALK_TIME / 2 ? .NONE : .HORIZONTAL
    clip = goomba_animation_clips[0]
  }

  rect = {
    x = cast(i32) ((position.x - 0.5 + offset.x) * tile_render_unit.x),
    y = cast(i32) ((position.y - 0.5 + offset.y) * tile_render_unit.y),
    w = cast(i32) (tile_render_unit.x), 
    h = cast(i32) (tile_render_unit.y),
  }

  sdl.RenderCopyEx(renderer, entities_texture.sdl_texture, &clip, &rect, 0, nil, flip)
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

update_entity :: proc(using entity: ^Entity) -> bool {
  if entity == nil do return true

  #partial switch base.tag {
    case .GOOMBA  : update_goomba  (&goomba  ) or_return
    case .MUSHROOM: update_mushroom(&mushroom) or_return
    case .SHELL   : update_shell   (&shell   ) or_return
  }

  return true
}

GOOMBA_DEAD_TIME  :: 30
GOOMBA_WALK_TIME  :: 20

GOOMBA_WALK_SPEED : f32 = 0.025

update_goomba :: proc(goomba: ^Goomba) -> bool {
  using goomba
  position_prev = position

  anim_clock += 1
  if is_dead {
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

  velocity.y = min(Plumber_Physics.max_fall_speed, velocity.y + Plumber_Physics.fall_gravity) 
  position += velocity

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
      if tile != nil && tile.bump_clock > 0 {
        velocity.y -= 0.3
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
        is_dead = true
        anim_clock = 0
        p.velocity.y = -Plumber_Physics.bounce_force
      }
    }
  }

  // check if the goomba has fallen out of the level
  if position.y > SCREEN_TILE_HEIGHT + 1 {
    return false
  }

  return true
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
      if tile != nil && tile.bump_clock > 0 {
        velocity.y -= 0.3
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
      p.powerup = max(p.powerup, Powerup.SUPER)
      return false
    }
  }

  // check if the mushroom has fallen out of the level
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

get_entity_collision_rect :: proc(using entity: Entity) -> sdl.FRect {
  #partial switch base.tag {
    case .GOOMBA   : return get_goomba_collision_rect  (goomba  )
    case .MUSHROOM : return get_mushroom_collision_rect(mushroom)
    case .SHELL    : return get_shell_collision_rect   (shell   )
  }
  return {}
}

frect_from_position_size_offset :: proc(position, size, offset: Vector2) -> sdl.FRect {
  return sdl.FRect {
    x = position.x + offset.x,
    y = position.y + offset.y,
    w = size.x,
    h = size.y,
  }
}

rect_from_position_size_offset :: proc(position, size, offset: Vector2) -> sdl.Rect {
  return sdl.Rect {
    x = i32(position.x + offset.x),
    y = i32(position.y + offset.y),
    w = i32(size.x),
    h = i32(size.y),
  }
}
