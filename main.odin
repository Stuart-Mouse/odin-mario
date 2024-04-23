package main

import "core:fmt"
import "core:math"
import "core:mem"
import "core:math/rand"
import "core:strings"
import "core:strconv"
import sdl       "vendor:sdl2"
import sdl_image "vendor:sdl2/image"
import sdl_mixer "vendor:sdl2/mixer"

import imgui "shared:imgui"
import "shared:imgui/imgui_impl_sdl2"
import "shared:imgui/imgui_impl_sdlrenderer2"

app_quit : bool = false

WINDOW_TITLE  :: "Super Plumber Brothers"
WINDOW_WIDTH  : i32 = 640
WINDOW_HEIGHT : i32 = 480

window   : ^sdl.Window
renderer : ^sdl.Renderer
small_text_texture : Texture

ProgramMode :: enum {
  GAME,
  EDITOR,
}

program_mode : ProgramMode = .GAME

ProgramInputKeys :: enum {
  SET_MODE_GAME,
  SET_MODE_EDITOR,
  RELOAD_SCREEN,
  SHOW_DEBUG_WINDOW,
  TOGGLE_IMGUI_RENDER_ABOVE,
  PAUSE,
  STEP_FRAME,
  RESET,
  COUNT,
}

program_controller : [ProgramInputKeys.COUNT] InputKey = {
  ProgramInputKeys.SET_MODE_GAME     = { sc = .F1 },
  ProgramInputKeys.SET_MODE_EDITOR   = { sc = .F2 },
  ProgramInputKeys.RELOAD_SCREEN     = { sc = .F4 },
  ProgramInputKeys.SHOW_DEBUG_WINDOW = { sc = .F5 },

  ProgramInputKeys.PAUSE      = { sc = .F9  },
  ProgramInputKeys.STEP_FRAME = { sc = .F10 },

  ProgramInputKeys.RESET = { sc = .F6 },

}

GameState : struct {
  active_level : Level_Data,
  paused : bool,
}

Level_Data :: struct {
  plumber   : Plumber,
  tilemap   : Tilemap,
  entities  : SlotArray(Entity, 64),
  camera    : Camera,
  clock     : u64,

  particles : [3]SlotArray(Particle, 64),
}

Camera :: struct {
  using position : Vector2
}

init_application :: proc() -> bool {
  if sdl.Init({.VIDEO, .AUDIO}) < 0 {
    fmt.println("sdl could not initialize! sdl Error: %", sdl.GetError())
    return false
  }
  sdl.SetHint(sdl.HINT_RENDER_SCALE_QUALITY, "0")

  if sdl_mixer.OpenAudio(44100, sdl.AUDIO_S16SYS, 2, 512) < 0 {
    fmt.println("Unable to open audio: %s\n", sdl.GetError())
    return false
  }

	if sdl_image.Init({.PNG}) == nil {
		fmt.println("sdl.image could not initialize! sdl.mage Error: %\n", sdl_image.GetError())
		return false
	}

  window = sdl.CreateWindow(
		WINDOW_TITLE, sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED,
		WINDOW_WIDTH, WINDOW_HEIGHT, sdl.WINDOW_SHOWN,
  )
	if window == nil {
		fmt.println("Window could not be created! sdl Error: %s\n", sdl.GetError())
		return false
	}

  renderer = sdl.CreateRenderer(window, -1, {.ACCELERATED, .PRESENTVSYNC})
	if renderer == nil {
		fmt.println("Renderer could not be created! sdl Error: %s\n", sdl.GetError())
		return false
	}

  small_text_texture = load_texture(renderer, "data/gfx/8x8_text.png" ) or_return
  plumber_texture    = load_texture(renderer, "data/gfx/plumber.png"  ) or_return
  tiles_texture      = load_texture(renderer, "data/gfx/blocks.png"   ) or_return
  entities_texture   = load_texture(renderer, "data/gfx/entities.png" ) or_return
  decor_texture      = load_texture(renderer, "data/gfx/decor.png"    ) or_return


	imgui.CHECKVERSION()
	imgui.CreateContext(nil)
	io := imgui.GetIO()
	io.ConfigFlags += { .NavEnableKeyboard, .NavEnableGamepad }

	imgui_impl_sdl2.InitForSDLRenderer(window, renderer)
	imgui_impl_sdlrenderer2.Init(renderer)

  return true
}

init_game :: proc() -> bool {
  {
    using GameState.active_level

    init_plumber_controller(&plumber)
    plumber.position = { SCREEN_TILE_WIDTH / 2, SCREEN_TILE_HEIGHT / 2 }
    plumber.scale = { 1, 1 }
  
    load_tile_info()
  
    init_plumber_physics()
  
    init_tilemap(&tilemap)
  
    position_x : f32 = 0.0
    for position_x < LEVEL_TILE_WIDTH {
      position_x += f32(SCREEN_TILE_WIDTH) * (rand.float32() * 0.5 + 0.5)
      using GameState.active_level
      slot := get_next_slot(&particles[1])
      slot.occupied = true
      slot.data = {
        velocity = { -(0.01 + rand.float32() * 0.05), 0 },
        position = { position_x, rand.float32() * 4 },
        scale    = { 1, 1 },
        animation = {
        frame_count = 1,
          frames = {
            {
              clip = { 0, 0, 48, 24 },
            },
            {}, {}, {}, {}, {}, {}, {},
          },
        },
        texture  = decor_texture.sdl_texture,
      }
    }
  }

  {
    using EditorState
    selected_type = Tile
    init_tilemap(&editting_level.tilemap)
    editting_level.plumber.position = { SCREEN_TILE_WIDTH / 2, SCREEN_TILE_HEIGHT / 2 }
    editting_level.plumber.scale = { 1, 1 }
  }

  return true
}

update_game :: proc() {
  using GameState.active_level
  update_plumber(&plumber)
  for &slot, i in entities.slots {
    if slot.occupied {
      if !update_entity(&slot.data) {
        slot.occupied = {}
      }
    }
  }
  for &bank in particles {
    for &slot in bank.slots {
      if slot.occupied {
        if !update_particle(&slot.data) do slot.occupied = {}
      }
    } 
  }

  @static cloud_clock : int
  cloud_clock -= 1
  if cloud_clock <= 0 {
    cloud_clock = int(rand.int31_max(480) + 60)
    using GameState.active_level
    slot := get_next_slot(&particles[1])
    slot.occupied = true
    slot.data = {
      velocity  = { -(0.01 + rand.float32() * 0.05), 0 },
      position  = { LEVEL_TILE_WIDTH + 2, rand.float32() * 4 },
      scale     = { 1, 1 },
      texture   = decor_texture.sdl_texture,
      animation = {
        frame_count = 1,
        frames = {
          {
            clip = { 0, 0, 48, 24 },
          },
          {}, {}, {}, {}, {}, {}, {},
        },
      },
    }
  }
}

render_game :: proc() {
  using GameState.active_level
  for &slot in particles[1].slots {
    if slot.occupied do render_particle(&slot.data, TILE_RENDER_SIZE, -camera.position)
  }
  render_tilemap(&tilemap, TILE_RENDER_SIZE, -camera.position)
  render_small_text("MARIO", {32, 16}, 0, 0, 2)
  render_small_text(fmt.tprintf("%6v", plumber.score), {32, 32}, 0, 0, 2)
  render_plumber(&plumber, TILE_RENDER_SIZE, -camera.position)
  for &slot in entities.slots {
    if slot.occupied do render_entity(slot.data, TILE_RENDER_SIZE, -camera.position)
  }
  for &slot in particles[0].slots {
    if slot.occupied do render_particle(&slot.data, TILE_RENDER_SIZE, -camera.position)
  }
}

close_application :: proc() {
    imgui_impl_sdlrenderer2.Shutdown()
    imgui_impl_sdl2.Shutdown()
    imgui.DestroyContext(nil)

    // sdl_mixer.FreeChunk(sound_bloop_1)
    // sdl_mixer.FreeChunk(sound_bloop_2)
    // sdl_mixer.CloseAudio()
    
    sdl.DestroyRenderer(renderer)
    sdl.DestroyWindow(window)
    sdl.Quit()
}

handle_sdl_events :: proc() {
  e : sdl.Event
  for sdl.PollEvent(&e) {
    imgui_impl_sdl2.ProcessEvent(&e)
    #partial switch e.type {
      case .QUIT:
        app_quit = true
      case .MOUSEWHEEL:
        Mouse.wheel.x = e.wheel.x;
        Mouse.wheel.y = e.wheel.y;
        Mouse.wheel_updated = 1;
    }
  }
}

main :: proc() {
  if !init_application() do return
  if !init_game() do return

  for !app_quit {
    handle_sdl_events()

    update_mouse()

    update_input_controller(program_controller[:])
    if program_controller[ProgramInputKeys.SET_MODE_EDITOR].state == KEYSTATE_PRESSED {
      program_mode = .EDITOR
    }
    if program_controller[ProgramInputKeys.SET_MODE_GAME].state == KEYSTATE_PRESSED {
      program_mode = .GAME
    }
    if program_controller[ProgramInputKeys.SHOW_DEBUG_WINDOW].state == KEYSTATE_PRESSED {
      show_debug_window = !show_debug_window
    }
    if program_controller[ProgramInputKeys.PAUSE].state == KEYSTATE_PRESSED {
      GameState.paused = !GameState.paused
    }
    if program_controller[ProgramInputKeys.RESET].state == KEYSTATE_PRESSED {
      GameState.active_level = EditorState.editting_level
      init_plumber_controller(&GameState.active_level.plumber)
      position_x : f32 = 0.0
      for position_x < LEVEL_TILE_WIDTH {
        position_x += f32(SCREEN_TILE_WIDTH) * (rand.float32() * 0.5 + 0.5)
        using GameState.active_level
        slot := get_next_slot(&particles[1])
        slot.occupied = true
        slot.data = {
          velocity = { -(0.01 + rand.float32() * 0.05), 0 },
          position = { position_x, rand.float32() * 4 },
          scale    = { 1, 1 },
          animation = {
            frame_count = 1,
            frames = {
              {
                clip     = { 0, 0, 48, 24 },
              },
              {}, {}, {}, {}, {}, {}, {},
            },
          },
          texture = decor_texture.sdl_texture,
        }
      }
    }

    sdl.SetRenderDrawColor(renderer, u8(sky_color.r * 255), u8(sky_color.g * 255), u8(sky_color.b * 255), u8(sky_color.a * 255))
    sdl.RenderClear(renderer)

    update_tile_animations()
    update_tilemap(&GameState.active_level.tilemap)

    imgui_new_frame()
    imgui_update()
    switch(program_mode) {
      case .GAME:
        if !GameState.paused || program_controller[ProgramInputKeys.STEP_FRAME].state == KEYSTATE_PRESSED {
          update_game()
        }
        render_game()
      case .EDITOR:
        update_editor()
        render_editor()
    }
    imgui_render()
    
    sdl.RenderPresent(renderer)
  }

  close_application()
}

imgui_new_frame :: proc() {
  imgui_impl_sdlrenderer2.NewFrame()
  imgui_impl_sdl2.NewFrame()
  imgui.NewFrame()
}

imgui_update :: proc() {
  if show_debug_window {
    flags : imgui.WindowFlags = { .NoNavInputs, .NoTitleBar, .NoCollapse, .NoMove }
    viewport : ^imgui.Viewport = imgui.GetMainViewport()
    imgui.SetNextWindowPos(viewport.Pos, .Always)
    imgui.SetNextWindowSize(viewport.Size, .Always)
    imgui.SetNextWindowBgAlpha(0.8)
    if imgui.Begin("Debug Window", &show_debug_window, flags) {
      if imgui.CollapsingHeader("Plumber Physics", {}) {
        using Plumber_Physics
        format : cstring = "%.4f"
        if imgui.SliderFloatEx("Jump Gravity"           , &jump_gravity          , 0,  0.1 , format, {}) do calc_plumber_physics()
        if imgui.SliderFloatEx("Fall Gravity"           , &fall_gravity          , 0,  0.1 , format, {}) do calc_plumber_physics()
        if imgui.SliderFloatEx("Jump Height"         , &jump_height       , 0, 10   , format, {}) do calc_plumber_physics()
        if imgui.SliderFloatEx("Run Jump Height"     , &run_jump_height   , 0, 10   , format, {}) do calc_plumber_physics()
        if imgui.SliderFloatEx("Jump Release Height"  , &jump_release_height, 0,  1   , format, {}) do calc_plumber_physics()
        if imgui.SliderFloatEx("Bounce Height"        , &bounce_height      , 0,  5   , format, {}) do calc_plumber_physics()
        imgui.SliderFloatEx("Walk Acceleration"   , &walk_accel       , 0,  0.01, format, {}) 
        imgui.SliderFloatEx("Run Acceleration"    , &run_accel        , 0,  0.01, format, {}) 
        imgui.SliderFloatEx("Walk Speed"          , &walk_speed       , 0,  0.5 , format, {}) 
        imgui.SliderFloatEx("Run Speed"           , &run_speed        , 0,  0.5 , format, {}) 
        imgui.SliderFloatEx("Skid Deceleration"   , &skid_decel       , 0,  0.01, format, {}) 
        imgui.SliderFloatEx("Release Deceleration", &release_decel    , 0,  0.01, format, {}) 
        imgui.SliderFloatEx("Ceiling Hit"         , &hit_ceiling      , 0,  1   , format, {}) 
        imgui.SliderFloatEx("Max Fall Speed"      , &max_fall_speed   , 0,  1   , format, {}) 
        imgui.SliderFloatEx("Air Acceleration"    , &air_accel        , 0,  0.01, format, {}) 
        imgui.SliderFloatEx("Air Deceleration"    , &air_decel        , 0,  0.01, format, {}) 
        if imgui.SliderFloatEx("Coyote Time"    , &coyote_time        , 0,  1, format, {})  do calc_plumber_physics()
        imgui.Checkbox("Show Plumber Collision Points", &show_plumber_collision_points)
      }

      if imgui.CollapsingHeader("Other", {}) {
        imgui.ColorEdit4("Sky Color", &sky_color, {})
        imgui.SliderFloat("Goomba Walk Speed", &GOOMBA_WALK_SPEED, 0, 0.4) 
      }
      if imgui.CollapsingHeader("Save / Load Level", {}) {
        @static level_path_buf : [64] u8 
        imgui.InputText("Level File Path", cstring(&level_path_buf[0]), len(level_path_buf), {})
        if imgui.Button("Save Level") {
          buf : [64] u8
          save_level(fmt.bprintf(buf[:], "data/levels/%v.lvl", cstring(&level_path_buf[0])))
        }
        imgui.SameLine()
        if imgui.Button("Load Level") {
          buf : [64] u8
          load_level(fmt.bprintf(buf[:], "data/levels/%v.lvl", cstring(&level_path_buf[0])))
        }
      }

      imgui.TreeNodeAny("Plumber", GameState.active_level.plumber, {})
    }
    imgui.End()
  }

  // imgui.ShowDemoWindow(nil)
}

imgui_render :: proc() {
  imgui.Render()
  imgui_impl_sdlrenderer2.RenderDrawData(imgui.GetDrawData())
}

show_debug_window : bool

sky_color : Color4 = { 
  f32(0x89) / f32(0xff), 
  f32(0x80) / f32(0xff), 
  f32(0xf4) / f32(0xff), 
  f32(0xff) / f32(0xff), 
}



