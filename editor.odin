package main

import sdl "vendor:sdl2"
import "core:fmt"
import "core:math"
import "shared:imgui"

EditorInputKeys :: enum {
  UP,
  DOWN,
  LEFT,
  RIGHT,
  TOGGLE_TILE_PICKER,
  CAMERA_DRAG,
  SET_PLAYER_START,
  COUNT,
}

editor_controller : [EditorInputKeys.COUNT] InputKey = {
    EditorInputKeys.UP    = { sc = .UP    },
	EditorInputKeys.DOWN  = { sc = .DOWN  },
	EditorInputKeys.LEFT  = { sc = .LEFT  },
	EditorInputKeys.RIGHT = { sc = .RIGHT },
	EditorInputKeys.TOGGLE_TILE_PICKER = { sc = .T },
	EditorInputKeys.CAMERA_DRAG = { sc = .SPACE },
	EditorInputKeys.SET_PLAYER_START = { sc = .P },
}

EditorState : struct {
    mouse_tile_index    : i32,
	selected_type	      : typeid,
	selected_entity	    : Entity,
    selected_tile_id    : u32,
    show_tile_picker    : bool,
    camera              : Camera,
    mouse_tile_position : Vector2,
  
    editting_level : Level_Data,
}

EDITOR_TILE_UNIT : f32 = 32.0

// TILE_PICKER_TILE_RENDER_UNIT  :: 32
// TILE_PICKER_TILE_MARGIN       :: 3 
// TILE_PICKER_TILE_SLOT_UNIT    :: TILE_PICKER_TILE_RENDER_UNIT + TILE_PICKER_TILE_MARGIN * 2
// TILE_PICKER_TILES_PER_ROW     :: 16
// TILE_PICKER_ROW_RENDER_WIDTH  :: TILE_PICKER_TILES_PER_ROW * TILE_PICKER_TILE_SLOT_UNIT
// TILE_PICKER_TOP_MARGIN        :: 32

// /*
//   TODO: implement a stack allocator for undo / redo?
// */
update_editor :: proc() {
  using EditorState
  using EditorInputKeys
  using GameState

  update_input_controller(editor_controller[:])

  CAMERA_MOVE_SPEED :: 0.2

  if bool(editor_controller[UP].state & KEYSTATE_PRESSED) {
    camera.y -= CAMERA_MOVE_SPEED
  }
  if bool(editor_controller[DOWN].state & KEYSTATE_PRESSED) {
    camera.y += CAMERA_MOVE_SPEED
  }
  if bool(editor_controller[LEFT].state & KEYSTATE_PRESSED) {
    camera.x -= CAMERA_MOVE_SPEED
  }
  if bool(editor_controller[RIGHT].state & KEYSTATE_PRESSED) {
    camera.x += CAMERA_MOVE_SPEED
  }

  if bool(editor_controller[CAMERA_DRAG].state & KEYSTATE_DOWN) {
    mouse_tile_velocity := pixel_to_internal_units(
      pixel_position  = Mouse.velocity, 
      internal_unit   = EDITOR_TILE_UNIT, 
    )
    camera.position -= mouse_tile_velocity
  }

  if Mouse.wheel.x != 0 {
    EDITOR_TILE_UNIT = clamp(EDITOR_TILE_UNIT + f32(Mouse.wheel.x), 16, 32)
  }

  if Mouse.wheel.y != 0 {
    selected_tile_id = cast(u32)clamp(i32(selected_tile_id) + Mouse.wheel.y, 0, i32(len(tile_info_lookup)-1))
  }

  screen_render_width  := EDITOR_TILE_UNIT * SCREEN_TILE_WIDTH
  screen_render_height := EDITOR_TILE_UNIT * SCREEN_TILE_HEIGHT

  tilemap := &editting_level.tilemap

  // get mouse position in the game world
  mouse_tile_position = pixel_to_internal_units(
    pixel_position  = Mouse.position, 
    internal_unit   = EDITOR_TILE_UNIT, 
    internal_offset = camera.position, 
  )
  // get the index of the hovered tile in the tilemap
  mouse_tile_index = get_grid_index_checked(
    position  = mouse_tile_position, 
    tile_size = { 1, 1 }, 
    grid_size = tilemap.size,
  )

  if Mouse.middle == KEYSTATE_PRESSED {
    tile := get_tile(tilemap, mouse_tile_index)
    if tile != nil do selected_tile_id = tile.id
  }
  if Mouse.left & KEYSTATE_PRESSED != 0 {
    if selected_type == Tile {
      tile := get_tile(tilemap, mouse_tile_index)
      if tile != nil {
        info := get_tile_info(tile^)
        tile^ = { id = selected_tile_id }
      }
    }
    else if selected_type == Entity && Mouse.left == KEYSTATE_PRESSED {
      slot := get_next_empty_slot(&editting_level.entities)
      if slot != nil {
        slot.occupied = true
        // init_entity(&slot.data, selected_entity)
        slot.data = selected_entity
        slot.data.base.position = {
          snap_to_nearest_unit(mouse_tile_position.x, 0.5),
          snap_to_nearest_unit(mouse_tile_position.y, 0.5),
        }
      }
    }
  }

  if bool(editor_controller[SET_PLAYER_START].state & KEYSTATE_PRESSED) {
    editting_level.plumber.position = {
      snap_to_nearest_unit(mouse_tile_position.x, 0.5),
      snap_to_nearest_unit(mouse_tile_position.y, 0.5),
    }
  }

  @static entity_details_popup_target : ^Slot(Entity)
  @static tile_details_popup_target : ^Tile

  if Mouse.right == KEYSTATE_PRESSED {
    clicked_entity := false
    for &slot in editting_level.entities.slots {
	    e     := &slot.data
	    frect := get_entity_collision_rect(e^)
	    if is_point_within_frect(mouse_tile_position, frect) {
            clicked_entity = true
            entity_details_popup_target = &slot
            imgui.OpenPopup("Entity Details Popup", {})
	    }
    }
    if !clicked_entity {
      tile := get_tile(tilemap, mouse_tile_index)
      if tile != nil {
        info := get_tile_info(tile^)
        if .CONTAINER in info.collision.flags {
          tile_details_popup_target = tile
          imgui.OpenPopup("Tile Details Popup", {})
        }
      }
    }
  }

  if imgui.BeginPopup("Tile Details Popup", {}) {
    if tile_details_popup_target == nil {
      imgui.CloseCurrentPopup()
    } else {
      img_size, img_uv0, img_uv1 : imgui.Vec2
      img_size = { 16, 16 }
      img_uv0  = {  0,  0 }
      img_uv1  = { 
        16 / f32(entities_texture.width ), 
        16 / f32(entities_texture.height),
      }
      if imgui.ImageButtonEx("Goomba", entities_texture.sdl_texture, img_size, img_uv0, img_uv1, {}, { 1, 1, 1, 1 }) {
        tile_details_popup_target.contains = .GOOMBA
        imgui.CloseCurrentPopup()
      }
      img_size = { 16, 16 }
      img_uv0  = { 
        32 / f32(entities_texture.width ), 
         0 / f32(entities_texture.height),
      }
      img_uv1  = { 
        48 / f32(entities_texture.width ), 
        16 / f32(entities_texture.height),
      }
      imgui.SameLine()
      if imgui.ImageButtonEx("Mushroom", entities_texture.sdl_texture, img_size, img_uv0, img_uv1, {}, { 1, 1, 1, 1 }) {
        tile_details_popup_target.contains = .MUSHROOM
        imgui.CloseCurrentPopup()
      }
      img_uv0  = { 
        32 / f32(entities_texture.width ), 
        16 / f32(entities_texture.height),
      }
      img_uv1  = { 
        48 / f32(entities_texture.width ), 
        32 / f32(entities_texture.height),
      }
      imgui.SameLine()
      if imgui.ImageButtonEx("Shell", entities_texture.sdl_texture, img_size, img_uv0, img_uv1, {}, { 1, 1, 1, 1 }) {
        tile_details_popup_target.contains = .SHELL
        imgui.CloseCurrentPopup()
      }
      img_uv0  = { 
         0 / f32(entities_texture.width ), 
        16 / f32(entities_texture.height),
      }
      img_uv1  = { 
        16 / f32(entities_texture.width ), 
        32 / f32(entities_texture.height),
      }
      imgui.SameLine()
      if imgui.ImageButtonEx("Beetle", entities_texture.sdl_texture, img_size, img_uv0, img_uv1, {}, { 1, 1, 1, 1 }) {
        tile_details_popup_target.contains = .BEETLE
        imgui.CloseCurrentPopup()
      }
      img_uv0  = { 
        f32(koopa_animation_clips[0].x) / f32(entities_texture.width ), 
        f32(koopa_animation_clips[0].y) / f32(entities_texture.height),
      }
      img_uv1  = { 
        f32(koopa_animation_clips[0].x + 16) / f32(entities_texture.width ), 
        f32(koopa_animation_clips[0].y + 16) / f32(entities_texture.height),
      }
      imgui.SameLine()
      if imgui.ImageButtonEx("Koopa", entities_texture.sdl_texture, img_size, img_uv0, img_uv1, {}, { 1, 1, 1, 1 }) {
        tile_details_popup_target.contains = .KOOPA
        imgui.CloseCurrentPopup()
      }
    }
    imgui.EndPopup()
  }

  if imgui.BeginPopup("Entity Details Popup", {}) {
    if entity_details_popup_target == nil {
      imgui.CloseCurrentPopup()
    } else {
      // imgui.TreeNodeAny("Entity", entity_details_popup_target.data)
      if imgui.Button("Delete") {
        entity_details_popup_target^ = {}
        entity_details_popup_target = nil
      }
    }
    imgui.EndPopup()
  }

  if editor_controller[TOGGLE_TILE_PICKER].state == KEYSTATE_PRESSED {
    show_tile_picker = !show_tile_picker
  }

  if show_tile_picker {
    flags : imgui.WindowFlags = { .NoNavInputs }
    img_size, img_uv0, img_uv1 : imgui.Vec2

    if imgui.Begin("Tile Picker", &show_tile_picker, flags) {
      imgui.SeparatorText("Tiles")
      for &tile_info, tile_id in tile_info_lookup {
        tri := get_tile_render_info({ id = u32(tile_id) })
        if tile_id % 8 != 0 do imgui.SameLine()
        img_size = { 16, 16 }
        img_uv0  = { 
          f32(tri.clip.x) / f32(tiles_texture.width ), 
          f32(tri.clip.y) / f32(tiles_texture.height),
        }
        img_uv1  = img_uv0 + { 
          TILE_TEXTURE_SIZE / f32(tiles_texture.width ), 
          TILE_TEXTURE_SIZE / f32(tiles_texture.height),
        }

        if imgui.ImageButtonEx(cstring(&tile_info.name[0]), tiles_texture.sdl_texture, img_size, img_uv0, img_uv1, {}, { 1, 1, 1, 1 }) {
          selected_type    = Tile
          selected_tile_id = u32(tile_id)
        }
        imgui.SetItemTooltip(cstring(&tile_info.name[0]))
      }
    }

	imgui.SeparatorText("Entities")
    img_uv0  = {  0,  0 }
    img_uv1  = { 
      16 / f32(entities_texture.width ), 
      16 / f32(entities_texture.height),
    }
    if imgui.ImageButtonEx("Goomba", entities_texture.sdl_texture, img_size, img_uv0, img_uv1, {}, { 1, 1, 1, 1 }) {
      selected_type   = Entity
      init_entity(&selected_entity, .GOOMBA)
    }
    img_size = { 16, 16 }
    img_uv0  = { 
      32 / f32(entities_texture.width ), 
       0 / f32(entities_texture.height),
    }
    img_uv1  = { 
      48 / f32(entities_texture.width ), 
      16 / f32(entities_texture.height),
    }
    imgui.SameLine()
    if imgui.ImageButtonEx("Mushroom", entities_texture.sdl_texture, img_size, img_uv0, img_uv1, {}, { 1, 1, 1, 1 }) {
      selected_type   = Entity
      init_entity(&selected_entity, .MUSHROOM)
    }
    img_uv0  = { 
      32 / f32(entities_texture.width ), 
      16 / f32(entities_texture.height),
    }
    img_uv1  = { 
      48 / f32(entities_texture.width ), 
      32 / f32(entities_texture.height),
    }
    imgui.SameLine()
    if imgui.ImageButtonEx("Shell", entities_texture.sdl_texture, img_size, img_uv0, img_uv1, {}, { 1, 1, 1, 1 }) {
      selected_type   = Entity
      init_entity(&selected_entity, .SHELL)
    }
    img_uv0  = { 
       0 / f32(entities_texture.width ), 
      16 / f32(entities_texture.height),
    }
    img_uv1  = { 
      16 / f32(entities_texture.width ), 
      32 / f32(entities_texture.height),
    }
    imgui.SameLine()
    if imgui.ImageButtonEx("Beetle", entities_texture.sdl_texture, img_size, img_uv0, img_uv1, {}, { 1, 1, 1, 1 }) {
      selected_type   = Entity
      init_entity(&selected_entity, .BEETLE)
    }
    img_uv0  = { 
      f32(koopa_animation_clips[0].x) / f32(entities_texture.width ), 
      f32(koopa_animation_clips[0].y) / f32(entities_texture.height),
    }
    img_uv1  = { 
      f32(koopa_animation_clips[0].x + 16) / f32(entities_texture.width ), 
      f32(koopa_animation_clips[0].y + 16) / f32(entities_texture.height),
    }
    imgui.SameLine()
    if imgui.ImageButtonEx("Koopa", entities_texture.sdl_texture, img_size, img_uv0, img_uv1, {}, { 1, 1, 1, 1 }) {
      selected_type   = Entity
      init_entity(&selected_entity, .KOOPA)
    }


    imgui.End()
  }

}

render_editor :: proc() {
  using EditorState
  using GameState

  sdl.RenderSetViewport(renderer, nil)
  sdl.SetRenderDrawColor(renderer, 0x22, 0x22, 0x55, 0xff)
  sdl.RenderClear(renderer)
  
  sdl.SetRenderDrawColor(renderer, u8(sky_color.r * 255), u8(sky_color.g * 255), u8(sky_color.b * 255), u8(sky_color.a * 255))
  sdl.RenderFillRect(renderer, &{
    x = i32(-camera.position.x * EDITOR_TILE_UNIT),
    y = i32(-camera.position.y * EDITOR_TILE_UNIT),
    w = editting_level.tilemap.size.x * i32(EDITOR_TILE_UNIT),
    h = editting_level.tilemap.size.y * i32(EDITOR_TILE_UNIT),
  })

  render_tilemap(&editting_level.tilemap, EDITOR_TILE_UNIT, -camera.position)
  render_plumber(&editting_level.plumber, EDITOR_TILE_UNIT, -camera.position)
  for &slot in editting_level.entities.slots {
    if slot.occupied do render_entity(slot.data, EDITOR_TILE_UNIT, -camera.position)
  }
  render_grid(
    { i32(EDITOR_TILE_UNIT), i32(EDITOR_TILE_UNIT) }, 
    { -i32(camera.position.x * EDITOR_TILE_UNIT), -i32(camera.position.y * EDITOR_TILE_UNIT) },
  )

  mouse_tile_rect := get_grid_tile_rect(
    mouse_tile_index, 
    { EDITOR_TILE_UNIT, EDITOR_TILE_UNIT }, 
    editting_level.tilemap.size, 
    -camera.position, 
  )
  
  if selected_type == Tile {
    tile := Tile{ id = selected_tile_id }
    if tile.id != 0 {
      tri := get_tile_render_info(tile)
      sdl.SetTextureColorMod(tri.texture, tri.color_mod.r, tri.color_mod.g, tri.color_mod.b)
      sdl.SetTextureAlphaMod(tri.texture, 0x88)
      sdl.RenderCopyF(renderer, tri.texture, &tri.clip, &mouse_tile_rect)
    }
    sdl.SetRenderDrawColor(renderer, 0xff, 0xff, 0xff, 0xff)
    sdl.RenderDrawRectF(renderer, &mouse_tile_rect)
  } else if selected_type == Entity {
		// temp_entity : Entity
		// init_entity(&temp_entity, selected_entity)
		render_entity(selected_entity, EDITOR_TILE_UNIT, {
			snap_to_nearest_unit(mouse_tile_position.x, 0.5),
			snap_to_nearest_unit(mouse_tile_position.y, 0.5),
		} - camera.position)
	}
}

render_grid_f :: proc(tile_size, offset: Vector2) {
  line_count_x : f32 = f32(WINDOW_WIDTH)  / tile_size.x + 1.0
  line_count_y : f32 = f32(WINDOW_HEIGHT) / tile_size.y + 1.0

  line_start_x : f32 = math.mod_f32(offset.x, tile_size.x)
  line_start_y : f32 = math.mod_f32(offset.y, tile_size.y)

  sdl.SetRenderDrawColor(renderer, 0x22, 0x22, 0x55, 0x88)
  for i: f32; i < line_count_x; i += 1 {
    x_pos := line_start_x + i * tile_size.x
    sdl.RenderDrawLineF(renderer, x_pos, 0, x_pos, f32(WINDOW_HEIGHT))
  }
  for i: f32; i < line_count_y; i += 1 {
    y_pos := line_start_y + i * tile_size.y
    sdl.RenderDrawLineF(renderer, 0, y_pos, f32(WINDOW_WIDTH), y_pos)
  }
}

render_grid :: proc(tile_size, offset: Vec2i) {
  line_count_x : i32 = WINDOW_WIDTH  / tile_size.x + 1.0
  line_count_y : i32 = WINDOW_HEIGHT / tile_size.y + 1.0

  line_start_x : i32 = offset.x % tile_size.x
  line_start_y : i32 = offset.y % tile_size.y

  sdl.SetRenderDrawColor(renderer, 0x22, 0x22, 0x55, 0x88)
  for i: i32; i < line_count_x; i += 1 {
    x_pos := line_start_x + i * tile_size.x
    sdl.RenderDrawLine(renderer, x_pos, 0, x_pos, WINDOW_HEIGHT)
  }
  for i: i32; i < line_count_y; i += 1 {
    y_pos := line_start_y + i * tile_size.y
    sdl.RenderDrawLine(renderer, 0, y_pos, WINDOW_WIDTH, y_pos)
  }
}

