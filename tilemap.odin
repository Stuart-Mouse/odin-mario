package main

import "core:os"
import "core:fmt"
import "core:mem"
import "core:math"
import "core:math/rand"
import "core:slice"
import sdl "vendor:sdl2"


tiles_texture : Texture

TILE_TEXTURE_SIZE :: 16
TILE_RENDER_SIZE  :: 32

Tile_Collision :: struct {
    type  : Tile_Collision_Type,
    flags : Tile_Collision_Flags,
}  

Tile_Collision_Type :: enum {
    BLOCK,
    COIN,
}

Tile_Collision_Flags :: bit_set[Tile_Collision_Flag]
Tile_Collision_Flag  :: enum {
    SOLID,      // the player will be pushed out of the tile
    BUMPABLE,   // will be bumped when hit, but not broken
    BREAKABLE,  // will break when hit
    CONTAINER,  // can have entities placed inside it
    HIDDEN,     // kaizo blocks
}

TILE_BUMP_TIME     :: 10
TILE_BUMP_DISTANCE :: 0.25

Tile_Flags :: bit_set[Tile_Flag]
Tile_Flag :: enum {
  BROKEN,
  EMPTIED,
  HIDDEN,
  CONTAINER_RELEASE_ALL_AT_ONCE,
}

Tile :: struct {
    id         : u32,
    flags      : Tile_Flags,
    bump_clock : u8,
    
    container : struct {
        entity_type  : Entity_Type,
        entity_param : struct #raw_union { item_type: Item_Type, enemy_template: u16 },
        count        : u16,
    }
}

// We could make this dynamic later on
MAX_TILE_ANIM_FRAMES :: 8

Tile_Info :: struct {
    name      : [32] u8,
    collision : Tile_Collision,
  
    // TODO: split into become_on_hit, become_on_broken, become_on_emptied or something 
    become_on_use : u32, // when a tile is bumped or broken, it will turn into this tile type
    
    // animations that act on a whole tile type
    animation : struct {
        frames  : [MAX_TILE_ANIM_FRAMES] struct {
            clip_offset : Vec2i,
            duration    : int,
        },
        frame_count   : int,
        current_frame : int,
        frame_clock   : int,
    },
}

update_tilemap :: proc(using tilemap: ^Tilemap) {
    for &tile, index in data {
        if tile.id == 0 do continue
        ti := get_tile_info(tile)
    
        if .BUMPABLE in ti.collision.flags {
            if tile.bump_clock > 0 {
                tile.bump_clock -= 1
                if tile.bump_clock == 0 {
                    if .BROKEN in tile.flags {
                        tile = {}
                    } else if .EMPTIED in tile.flags {
                        tile = { id = ti.become_on_use }
                    }
                }
            }
        }
    }
}

Tile_Bump_Type :: enum {
    SMALL_PLUMBER,
    
    BIG_PLUMBER,
    SHELL,
}

bump_tile :: proc(tilemap: ^Tilemap, tile_index: int, bump_type: Tile_Bump_Type, bump_dir: Direction) {
    tile := get_tile(tilemap, tile_index)
    
    if tile == nil do return
    ti := get_tile_info(tile^)
    
    if .BUMPABLE not_in ti.collision.flags do return 
    
    tile_position := Vector2 { f32(i32(tile_index) % tilemap.size.x), f32(i32(tile_index) / tilemap.size.x) }
    
    if tile.bump_clock == 0 {
        tile.bump_clock = TILE_BUMP_TIME

        if .CONTAINER in ti.collision.flags && tile.container.entity_type != .NONE {
            item_spawn_position := tile_position + { 0.5, -0.5 } // + direction_vectors[bump_dir]
            if .CONTAINER_RELEASE_ALL_AT_ONCE in tile.flags && tile.container.count > 1 {
                base_angle := direction_angles[.U] * math.PI / 180
                
                // speed at which items are ejected and spread of items get grater as we add more items, to a limit
                velocity_scalar := lerp(0.2,  0.5  , f32(min(i32(tile.container.count), 50)) / 50.0)
                spread          := lerp(0.00, 30.00, f32(min(i32(tile.container.count), 10)) / 10.0) * math.PI / 180
                
                min_angle := base_angle - spread
                max_angle := base_angle + spread
                
                for i in 0..<int(tile.container.count) {
                    slot := get_next_empty_slot(&GameState.active_level.entities)
                    if slot == nil do break
                    slot.occupied = true
                    
                    #partial switch tile.container.entity_type {
                        case .ITEM:
                            item := cast(^Item) &slot.data
                            init_item(item, tile.container.entity_param.item_type, .U)
                        case .ENEMY:
                            enemy := cast(^Enemy) &slot.data
                            init_enemy(enemy, int(tile.container.entity_param.enemy_template), .U)
                    }
                    
                    slot.data.base.position = item_spawn_position
                    slot.data.base.velocity = velocity_scalar * unit_vector_given_angle(lerp(min_angle, max_angle, f32(i) / f32(tile.container.count-1)))
                }
                
                tile.container.entity_type = .NONE
                tile.flags |= {.EMPTIED}
            }
            else {
                if tile.container.entity_type == .ITEM && tile.container.entity_param.item_type == .COIN {
                    plumber_add_coins(&GameState.active_level.plumber, 1, item_spawn_position)
                    spawn_coin_particle(item_spawn_position)
                } else {
                    slot := get_next_empty_slot(&GameState.active_level.entities)
                    if slot != nil {
                        slot.occupied = true
                        
                        #partial switch tile.container.entity_type {
                            case .ITEM:
                                item := cast(^Item) &slot.data
                                init_item(item, tile.container.entity_param.item_type)
                            case .ENEMY:
                                enemy := cast(^Enemy) &slot.data
                                init_enemy(enemy, int(tile.container.entity_param.enemy_template))
                        }
                        
                        slot.data.base.position = item_spawn_position
                        slot.data.base.velocity = { 0, -0.2 }
                    }
                }
                
                tile.container.count -= 1
                if tile.container.count <= 0 {
                    tile.container.entity_type = .NONE
                    tile.flags |= {.EMPTIED}
                }
            }
            
        }
        else if .BREAKABLE in ti.collision.flags {
            if bump_type >= .BIG_PLUMBER {
                tile.flags |= { .BROKEN }
                create_block_break_particles(
                    tile      = tile^,
                    position  = tile_position,
                    pieces    = { 2, 2 },
                    vel_x     = { -0.07,  0.07 },
                    vel_y     = { -0.35, -0.30 },
                    vel_ax    = { -7   ,  7    },
                    vel_var   = {  0.05,  0.05,  3 },
                    // vel_extra = velocity * { 0.5, 0 },
                )
            }
        }
    }
}

tile_info_lookup : [dynamic] Tile_Info

get_tile_info :: proc(tile: Tile) -> ^Tile_Info {
    if tile.id < 0 || int(tile.id) >= len(tile_info_lookup) {
        fmt.println("Error: tile id was out of range.")
        return nil
    }
    return &tile_info_lookup[tile.id]
}

update_tile_animations :: proc() {
    for i in 1..<len(tile_info_lookup) {
        ti := &tile_info_lookup[i]
        using ti.animation
        if frame_count > 1 {
            frame_clock += 1
            if frame_clock >= frames[current_frame].duration {
                current_frame += 1
                frame_clock = 0
                if current_frame >= frame_count {
                    current_frame  = 0
                }
            }
        }
    }
}

reset_tile_animations :: proc() {
  for i in 1..<len(tile_info_lookup) {
    ti := &tile_info_lookup[i]
    ti.animation.current_frame = 0
    ti.animation.frame_clock   = 0
  }
}

tile_dir_clips : [16] Vec2i = {
  int(Directions{}) = { 0, 0 },

  int(Directions{.U}) = { 1, 3 },
  int(Directions{.D}) = { 1, 0 },
  int(Directions{.L}) = { 3, 1 },
  int(Directions{.R}) = { 0, 1 },

  int(Directions{.U, .D}) = { 1, 2 },
  int(Directions{.U, .L}) = { 3, 3 },
  int(Directions{.U, .R}) = { 2, 3 },
  int(Directions{.D, .L}) = { 3, 2 },
  int(Directions{.D, .R}) = { 2, 2 },
  int(Directions{.L, .R}) = { 2, 1 },

  int(Directions{.U, .D, .L}) = { 0, 2 },
  int(Directions{.U, .D, .R}) = { 0, 3 },
  int(Directions{.U, .L, .R}) = { 2, 0 },
  int(Directions{.D, .L, .R}) = { 3, 0 },

  int(Directions{.U, .D, .L, .R}) = { 1, 1 },
}

Tile_Render_Info :: struct {
  texture       : ^sdl.Texture,
  clip          : sdl.Rect,
  render_offset : Vec2i,
  color_mod     : sdl.Color,
}

get_tile_render_info :: proc(tile: Tile) -> Tile_Render_Info {
  using tri : Tile_Render_Info;
  color_mod = tile.id == 0 ? {} : { 0xff, 0xff, 0xff, 0xff }

  ti := get_tile_info(tile)
  if ti == nil {
    fmt.println("Error: unable to retreive tile info.")
    return tri
  }

  tri.texture = tiles_texture.sdl_texture
  clip_offset := ti.animation.frames[ti.animation.current_frame].clip_offset

  clip = {
    x = clip_offset.x * TILE_TEXTURE_SIZE,
    y = clip_offset.y * TILE_TEXTURE_SIZE,
    w = TILE_TEXTURE_SIZE,
    h = TILE_TEXTURE_SIZE,
  }
  
  if .HIDDEN in tile.flags {
    tri.color_mod.a = 0xF
  }

  return tri
}

get_tile_collision :: proc(tile: Tile) -> Tile_Collision {
  info := get_tile_info(tile)
  collision := info.collision

  /* 
    If a breakable block has a bump_clock value greater than 0, then it is 
      currently broken, but pending deletion so that we can perform collision 
      with any entities that were standing on top of the block.
    In this case, we need to remove the .SOLID flag so that it cannot be stood upon.
  */ 
  if .BREAKABLE in collision.flags {
    if tile.bump_clock > 0 {
      collision.flags &= ~{ .SOLID }
    }
  }

  return get_tile_info(tile).collision
}

SCREEN_TILE_WIDTH  :: 20
SCREEN_TILE_HEIGHT :: 15

LEVEL_TILE_WIDTH   :: SCREEN_TILE_WIDTH * 12

// TODO: allocate the space for the tiles upon startup / level create
Tilemap :: struct {
  data : [LEVEL_TILE_WIDTH * SCREEN_TILE_HEIGHT] Tile,
  size : Vec2i,
}

init_tilemap :: proc(tilemap: ^Tilemap) {
  tilemap.size = { LEVEL_TILE_WIDTH, SCREEN_TILE_HEIGHT }
  for j in 0..<int(tilemap.size.x) {
    get_tile(tilemap,  j, 13)^ = { id = 1 }
    get_tile(tilemap,  j, 14)^ = { id = 1 }
  }
}

get_tile :: proc {
  get_tile_1D,
  get_tile_2D,
}

get_tile_1D :: proc(tilemap: ^Tilemap, i: int) -> ^Tile {
  if i < 0 || i >= int(tilemap.size.x) * int(tilemap.size.y) {
    return nil
  }
  return &tilemap.data[i]
}

get_tile_2D :: proc(tilemap: ^Tilemap, x, y: int) -> ^Tile {
  if x < 0 || x >= int(tilemap.size.x) ||
     y < 0 || y >= int(tilemap.size.y) {
    return nil
  }
  return &tilemap.data[y * int(tilemap.size.x) + x]
}

set_all_tiles_on_tilemap :: proc(tilemap: ^Tilemap, tile: Tile) {
  for i in 0..<tilemap.size.x * tilemap.size.y {
    tilemap.data[i] = tile
  }
}

render_tilemap :: proc(tilemap: ^Tilemap, tile_render_unit: f32, offset: Vector2) {
  offset := offset * tile_render_unit

  for y: i32; y < SCREEN_TILE_HEIGHT; y += 1 {
    for x: i32; x < LEVEL_TILE_WIDTH; x += 1 {
      tile := &tilemap.data[y * tilemap.size.x + x]

      if tile.id == 0          do continue
      if .BROKEN in tile.flags do continue

      tile_rect : sdl.FRect = {
        x = offset.x + f32(x) * tile_render_unit, 
        y = offset.y + f32(y) * tile_render_unit, 
        w = tile_render_unit,
        h = tile_render_unit,
      }

      // ti := get_tile_info(tile^)

      // add render offset for bumped tile
      if tile.bump_clock != 0 {
        lerp : f32 = f32(tile.bump_clock) / TILE_BUMP_TIME
        lerp = 1.0 - math.pow(1.0 - 2 * lerp, 2)
        tile_rect.y -= lerp * TILE_BUMP_DISTANCE * tile_render_unit
      }

      tri := get_tile_render_info(tile^)
      sdl.SetTextureColorMod(tri.texture, tri.color_mod.r, tri.color_mod.g, tri.color_mod.b)
      sdl.SetTextureAlphaMod(tri.texture, tri.color_mod.a)
      sdl.RenderCopyF(renderer, tri.texture, &tri.clip, &tile_rect)
    }
  }
}

Tilemap_Collision_Results :: struct {
    push_out        : Directions,
    push_out_dir    : [4] Direction,        // tells us which collision point was used to push the player out in the given direction
    indexed_tiles   : [Direction] int,
    points          : [Direction] Vector2,
    indices         : [Direction] Vec2i,
    resolutions     : [Direction] Direction, // really only used for corner cases, so we can see what which primary case they resolved to
    position_adjust : Vector2,
    velocity_adjust : Vector2,
    set_velocity    : bool,
}

do_tilemap_collision :: proc(tilemap: ^Tilemap, position, size, offset: Vector2, velocity: Vector2 = {}) -> Tilemap_Collision_Results {
    results : Tilemap_Collision_Results
    results.resolutions = { .U = .U, .D = .D, .L = .L, .R = .R, .UL = .UL, .UR = .UR, .DL = .DL, .DR = .DR }
    
    push_out     : Directions = {}
    push_out_dir : [4] Direction = { Direction(0), Direction(1), Direction(2), Direction(3) }
  
    points  : [Direction] Vector2
    indices : [Direction] Vec2i
  
    points[Direction.U].x = position.x + offset.x + size.x / 2
    points[Direction.U].y = position.y + offset.y
    points[Direction.D].x = position.x + offset.x + size.x / 2
    points[Direction.D].y = position.y + offset.y + size.y
    points[Direction.L].x = position.x + offset.x
    points[Direction.L].y = position.y + offset.y + size.y / 2
    points[Direction.R].x = position.x + offset.x + size.x
    points[Direction.R].y = position.y + offset.y + size.y / 2
  
    points[Direction.UR].x = points[Direction.R].x
    points[Direction.UR].y = points[Direction.U].y
    points[Direction.DR].x = points[Direction.R].x
    points[Direction.DR].y = points[Direction.D].y
    points[Direction.UL].x = points[Direction.L].x
    points[Direction.UL].y = points[Direction.U].y
    points[Direction.DL].x = points[Direction.L].x
    points[Direction.DL].y = points[Direction.D].y
  
    // convert points to indices
    for dir_i in Direction(0)..<Direction(8) {
        indices[dir_i].x = cast(i32) math.floor(points[dir_i].x)
        indices[dir_i].y = cast(i32) math.floor(points[dir_i].y)
    }
  
    // get collision at each point
    for dir_i in Direction(0)..<Direction(8) {
        if indices[dir_i].x < 0 || indices[dir_i].x >= tilemap.size.x do continue
        if indices[dir_i].y < 0 || indices[dir_i].y >= tilemap.size.y do continue
    
        tile_index_1d := int(indices[dir_i].y * tilemap.size.x + indices[dir_i].x)
    
        tile := get_tile(tilemap, tile_index_1d)
        if tile == nil do continue
        
        collision := get_tile_collision(tile^)
        if .SOLID in collision.flags {
            // not sure if I actually want to handle this here, like this. seems not ideal. but we need to refactor this proc out into multiple probably anyhow in the long term
            if .HIDDEN in tile.flags {
                y_frac := points[Direction.U].y - math.floor(points[Direction.U].y)
                if dir_i == .U && velocity.y < 0 && y_frac > 0.75 {
                    push_out |= { Direction(dir_i) }
                    tile.flags &= ~{.HIDDEN}
                }
            }
            else {
                push_out |= { Direction(dir_i) }
            }
        }
      
        results.indexed_tiles[Direction(dir_i)] = tile_index_1d
    }

    results.indices      = indices
    results.points       = points
    results.push_out     = push_out
    results.push_out_dir = push_out_dir
  
    // leave early if no points have collision
    if push_out == {} do return results
  
    // resolve corner cases into primary direction collision
    x_frac, y_frac : f32
    if (.UR in push_out) && (push_out & { .U, .R } == {})  {
        x_frac =       (points[Direction.UR].x - math.floor(points[Direction.UR].x))
        y_frac = 1.0 - (points[Direction.UR].y - math.floor(points[Direction.UR].y))
        if (x_frac > y_frac) {
            push_out |= { .U }
            push_out_dir[Direction.U] = Direction.UR
            results.resolutions[.UR] = .U
        } else {
            push_out |= { .R }
            push_out_dir[Direction.R] = Direction.UR
            results.resolutions[.UR] = .R
        }
    }
    if (.DR in push_out) && (push_out & { .D, .R } == {}) {
        x_frac = (points[Direction.DR].x - math.floor(points[Direction.DR].x))
        y_frac = (points[Direction.DR].y - math.floor(points[Direction.DR].y))
        if (x_frac > y_frac) {
            push_out |= { .D }
            push_out_dir[Direction.D] = Direction.DR
            results.resolutions[.DR] = .D
        } else {
            push_out |= { .R }
            push_out_dir[Direction.R] = Direction.DR
            results.resolutions[.DR] = .R
        }
    }
    if (.UL in push_out) && (push_out & { .U, .L } == {}) {
        x_frac = 1.0 - (points[Direction.UL].x - math.floor(points[Direction.UL].x))
        y_frac = 1.0 - (points[Direction.UL].y - math.floor(points[Direction.UL].y))
        if (x_frac > y_frac) {
            push_out |= { .U }
            push_out_dir[Direction.U] = Direction.UL
            results.resolutions[.UL] = .U
        } else {
            push_out |= { .L }
            push_out_dir[Direction.L] = Direction.UL
            results.resolutions[.UL] = .L
        }
    }
    if (.DL in push_out) && (push_out & { .D, .L } == {}) {
        x_frac = 1.0 - (points[Direction.DL].x - math.floor(points[Direction.DL].x))
        y_frac =       (points[Direction.DL].y - math.floor(points[Direction.DL].y))
        if (x_frac > y_frac) {
            push_out |= { .D }
            push_out_dir[Direction.D] = Direction.DL
            results.resolutions[.DL] = .D
        } else {
            push_out |= { .L }
            push_out_dir[Direction.L] = Direction.DL
            results.resolutions[.DL] = .L
        }
    }
    
    results.push_out = push_out
    
    // handle primary direction collision
    if .U in push_out {
        push_out_direction := push_out_dir[Direction.U]
        position_in_block  := 1.0 - (points[push_out_direction].y - f32(indices[push_out_direction].y))
        results.position_adjust.y += position_in_block;
    }
    if .D in push_out {
        push_out_direction := push_out_dir[Direction.D]
        position_in_block  := points[push_out_direction].y - f32(indices[push_out_direction].y)
        results.position_adjust.y -= position_in_block;
    }
    if .L in push_out {
        push_out_direction := push_out_dir[Direction.L]
        position_in_block  := 1.0 - (points[push_out_direction].x - f32(indices[push_out_direction].x))
        results.position_adjust.x += position_in_block;
    }
    if .R in push_out {
        push_out_direction := push_out_dir[Direction.R]
        position_in_block  := points[push_out_direction].x - f32(indices[push_out_direction].x)
        results.position_adjust.x -= position_in_block;
    }
  
    return results
}

tile_is_bumping :: proc(tile: Tile) -> bool {
    return tile.bump_clock > TILE_BUMP_TIME-2 //&& .BROKEN not_in tile.flags
}

save_level :: proc(path: string) {
    if !os.write_entire_file(path, mem.any_to_bytes(EditorState.editting_level)) {
        fmt.println("Failed to save level:", path)
        return
    }
    fmt.println("Saved level:", path)
}

load_level :: proc(path: string) {
    bytes, ok := os.read_entire_file(path)
    defer delete(bytes)
    if ok {
        dst := &EditorState.editting_level
        mem.copy(dst, &bytes[0], size_of(dst^))
        fmt.println("Loaded level:", path)
        return
    }
    fmt.println("Failed to load level:", path)
}

create_block_break_particles :: proc(
  tile      : Tile, 
  position  : Vector2, 
  pieces    : Vec2i,
  vel_y     : Vector2 = {},
  vel_x     : Vector2 = {},
  vel_ax    : Vector2 = {},
  vel_ay    : Vector2 = {},
  vel_extra : Vector2 = {},
  vel_var   : [3] f32 = {},
) {
  render_info := get_tile_render_info(tile)

  clip_size := Vector2 {
    f32(render_info.clip.w) / f32(pieces.x),
    f32(render_info.clip.h) / f32(pieces.y),
  }

  piece_size := Vector2 {
    1.0 / f32(pieces.x),
    1.0 / f32(pieces.y),
  }
  piece_offset := piece_size / 2

  for piece_x in 0..<pieces.x {
    for piece_y in 0..<pieces.y {
      vel_lerp := Vector2 {
        f32(piece_x) / f32(pieces.x - 1),
        f32(piece_y) / f32(pieces.y - 1),
      }
      vel_var := [3] f32 {
        vel_var.x * (rand.float32() - 0.5),
        vel_var.y * (rand.float32() - 0.5),
        vel_var.z * (rand.float32() - 0.5),
      }

      slot := get_next_slot(&GameState.active_level.particles[0])
      slot.occupied = true
      slot.data = {
        scale        = { 1, 1 },
        position     = position + piece_offset + piece_size * { f32(piece_x), f32(piece_y) },
        velocity     = vel_extra + vel_var.xy + {
          lerp(vel_x[0], vel_x[1], vel_lerp.x),
          lerp(vel_y[0], vel_y[1], vel_lerp.y),
        },
        acceleration = {  0, Plumber_Physics.fall_gravity },
        angular_velocity = lerp(vel_ax[0], vel_ax[1], vel_lerp.x) + lerp(vel_ay[0], vel_ay[1], vel_lerp.y) + vel_var.z,
        texture = tiles_texture.sdl_texture,
        animation = {
          frame_count = 1,
          frames = {
            {
              clip = {
                x = render_info.clip.x + i32(clip_size.x * f32(piece_x)),
                y = render_info.clip.y + i32(clip_size.y * f32(piece_y)),
                w = i32(clip_size.x),
                h = i32(clip_size.y),
              },
            },
            {}, {}, {}, {}, {}, {}, {},
          },
        },
      }
    }
  }
}

