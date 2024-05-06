package main

// import sdl "vendor:sdl2"
// import "core:fmt"

Powerup :: enum {
    NONE,
    SUPER,
    FIRE,
}

// // Now this is just a general powerup type
// Mushroom :: struct {
//     using base : Entity_Base,
//     walk_dir   : Direction,
//     powerup    : Powerup,
// }



// render_mushroom :: proc(mushroom: Mushroom, tile_render_unit, offset: Vector2) {
//     using GameState.active_level, mushroom
    
//     flip : sdl.RendererFlip
//     clip, rect : sdl.Rect
    
//     #partial switch mushroom.powerup {
//         case .SUPER:
//             clip = { 32, 0, 16, 16 }
//         case .FIRE:
//             @static frame_counter := 0
//             @static frame_index   := 0
            
//             fire_flower_clips := []struct { clip: sdl.Rect, duration: int } {
//                 { {  0, 80, 16, 16 }, 6 },
//                 { { 16, 80, 16, 16 }, 6 },
//                 { { 32, 80, 16, 16 }, 6 },
//                 { { 48, 80, 16, 16 }, 6 },
//             }
            
//             frame_counter += 1
//             if frame_counter >= fire_flower_clips[frame_index].duration {
//                 frame_index += 1
//                 frame_counter = 0
//                 if frame_index >= len(fire_flower_clips) {
//                     frame_index = 0
//                 }
//             }
            
//             clip = fire_flower_clips[frame_index].clip
//     }
    
//     rect = {
//         x = cast(i32) ((position.x - 0.5 + offset.x) * tile_render_unit.x),
//         y = cast(i32) ((position.y - 0.5 + offset.y) * tile_render_unit.y),
//         w = cast(i32) (tile_render_unit.x), 
//         h = cast(i32) (tile_render_unit.y),
//     }

//     sdl.RenderCopyEx(renderer, entities_texture.sdl_texture, &clip, &rect, 0, nil, flip)
// }

// update_mushroom :: proc(mushroom: ^Mushroom) -> bool {
//     using mushroom
//     position_prev = position

//     if powerup == .SUPER {
//         if walk_dir == .L {
//             position.x -= GOOMBA_WALK_SPEED 
//         } else if walk_dir == .R {
//             position.x += GOOMBA_WALK_SPEED 
//         }
//     }

//     friction : f32 = .ON_GROUND in flags ? 0.9 : 1
//     velocity.x *= friction

//     velocity.y = min(Plumber_Physics.max_fall_speed, velocity.y + Plumber_Physics.fall_gravity) 
//     position += velocity

//     flags &= ~{.ON_GROUND}
//     // do tilemap collision
//     {
//         tilemap := &GameState.active_level.tilemap
//         size, offset := get_mushroom_collision_size_and_offset(mushroom^)
//         using collision_result := do_tilemap_collision(tilemap, position, size, offset)
//         position += position_adjust
//         if .L in push_out {
//             if walk_dir == .L do walk_dir = .R
//             if velocity.x < 0 do velocity.x = 0
//         }
//         if .R in push_out {
//             if walk_dir == .R do walk_dir = .L
//             if velocity.x > 0 do velocity.x = 0
//         }
//         if .U in push_out {
//             if velocity.y < 0 do velocity.y = Plumber_Physics.hit_ceiling
//         }
//         if .D in push_out {
//             if velocity.y > 0 do velocity.y = 0
//             flags |= {.ON_GROUND}
//         }
//         for dir in ([]Direction {.D, .DL, .DR}) {
//             tile := get_tile(tilemap, indexed_tiles[dir])
//             if tile != nil && tile_is_bumping(tile^) {
//                 bump_dir := dir
//                 if bump_dir == .D {
//                     bump_dir = walk_dir
//                 }
//                 block_hit_entity(cast(^Entity)mushroom, bump_dir)
//                 break
//             }
//         }
//     }

//     // do collision with plumber
//     {
//         p      := &GameState.active_level.plumber
//         p_rect := get_plumber_collision_rect(p^)
//         m_rect := get_mushroom_collision_rect(mushroom^)

//         if aabb_frect(p_rect, m_rect) {
//             if p.powerup < .FIRE || p.powerup != powerup {
//                 change_plumber_powerup_state(p, powerup)
//             }
//             p.score += 1000
//             spawn_score_particle(5, position)
//             return false
//         }
//     }

//     // check if the mushroom has fallen out of the level
//     if position.y > SCREEN_TILE_HEIGHT + 1 {
//         return false
//     }

//     return true
// }

// get_mushroom_collision_rect :: proc(mushroom: Mushroom) -> sdl.FRect {
//     using mushroom
//     size, offset := get_mushroom_collision_size_and_offset(mushroom)
//     return {
//         x = position.x + offset.x,
//         y = position.y + offset.y,
//         w = size.x,
//         h = size.y,
//     }    
// }

// get_mushroom_collision_size_and_offset :: proc(using mushroom: Mushroom) -> (size, offset :Vector2) {
//     size     = scale * Vector2 { 14.0 / 16.0, 11.0 / 16.0 }
//     offset = -(size / 2) + {0, (1.0 / 16.0)}
//     return
// }
