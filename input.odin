package main

import SDL "vendor:sdl2"
import imgui "shared:imgui"

KeyState :: u32
KEYSTATE_RELEASED : KeyState = 0b0010
KEYSTATE_UP       : KeyState = 0b0000
KEYSTATE_PRESSED  : KeyState = 0b0001
KEYSTATE_DOWN     : KeyState = 0b0011

InputKey :: struct {
  mod   : SDL.Keymod,
  sc    : SDL.Scancode,
  state : KeyState
}

update_input_controller :: proc(controller: [] InputKey) {
  keymod := SDL.GetModState() & (SDL.KMOD_ALT | SDL.KMOD_CTRL | SDL.KMOD_SHIFT)
  /*
    KMOD_ALT, _CTRL, and _SHIFT include bit flags for both left and right variants.
    If any of these are set, we OR in the rest so that 
  */
  if keymod & SDL.KMOD_ALT   != {} do keymod |= SDL.KMOD_ALT
  if keymod & SDL.KMOD_CTRL  != {} do keymod |= SDL.KMOD_CTRL
  if keymod & SDL.KMOD_SHIFT != {} do keymod |= SDL.KMOD_SHIFT

  keyboard := SDL.GetKeyboardState(nil)
	for &key in controller {
		state : u32 = 0
		if key.mod == keymod {
			state |= u32(keyboard[key.sc])
		}
		key.state <<= 1
		key.state  |= state
		key.state  &= 0b11
	}
}

Mouse : struct {
	position      : Vec2i,
	position_prev : Vec2i,
	velocity      : Vec2i,
	left          : KeyState,
	middle        : KeyState,
	right         : KeyState,
	wheel         : Vec2i,
	wheel_updated : KeyState,
}

update_mouse :: proc() {
	if imgui.GetIO().WantCaptureMouse {
		Mouse.left   = {}
		Mouse.middle = {}
		Mouse.right  = {}
		Mouse.velocity = 0
		Mouse.wheel = { 0, 0 }
		return
	}

	Mouse.position_prev  = Mouse.position
	button_mask         := SDL.GetMouseState(&Mouse.position.x, &Mouse.position.y)
	Mouse.velocity       = Mouse.position - Mouse.position_prev
	Mouse.wheel_updated  = KeyState(u32(Mouse.wheel_updated) << 1)
	Mouse.wheel_updated  = KeyState(u32(Mouse.wheel_updated) & 0b11)
	if Mouse.wheel_updated == KEYSTATE_UP {
		Mouse.wheel = { 0, 0 }
  }
	state : u32
	state = u32(bool(button_mask & u32(SDL.BUTTON(SDL.BUTTON_LEFT  ))))
	Mouse.left   = ((state | (Mouse.left   << 1)) & 0b11)
	state = u32(bool(button_mask & u32(SDL.BUTTON(SDL.BUTTON_MIDDLE))))
	Mouse.middle = ((state | (Mouse.middle << 1)) & 0b11)
	state = u32(bool(button_mask & u32(SDL.BUTTON(SDL.BUTTON_RIGHT ))))
	Mouse.right  = ((state | (Mouse.right  << 1)) & 0b11)
}
