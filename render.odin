package main

import "core:fmt"
import "core:strings"
import "core:strconv"
import SDL       "vendor:sdl2"
import SDL_image "vendor:sdl2/image"
import SDL_mixer "vendor:sdl2/mixer"

Texture :: struct {
  sdl_texture   : ^SDL.Texture,
  width, height : int,
}

load_sdl_texture :: proc(renderer: ^SDL.Renderer, filename: string) -> (^SDL.Texture, bool) {
  c_filename := strings.clone_to_cstring(filename)
  defer delete(c_filename)
  texture := SDL_image.LoadTexture(renderer, c_filename)
  if texture == nil {
    fmt.printf("Unable to create texture from surface! SDL Error: %v\n", SDL.GetError())
    return nil, false
  }
  return texture, true
}

load_texture :: proc(renderer: ^SDL.Renderer, filename: string) -> (texture: Texture, ok: bool) {
  texture.sdl_texture, ok = load_sdl_texture(renderer, filename)
  if !ok do return {}, false
  w, h : i32
  SDL.QueryTexture(texture.sdl_texture, nil, nil, &w, &h)
  texture.width  = int(w)
  texture.height = int(h)
  return texture, true
}


// 8x8 bitmap text rendering functions

// text align ranges from 0-1, corresponding to where in the string to treat as the attachment point
// so for example, 0 is left-align, 0.5 is centered, 1 is right-aligned
render_small_text :: proc(text: string, position: Vec2i, max_len: int, text_align, scale: f32) {
  position := position
  str_len  := len(text)

  do_ellipsis := false
  if max_len > 0 && max_len < str_len {
    str_len = max_len - 2
    do_ellipsis = true
  }

  text_size  := int(8.0 * scale)
  position.x -= i32(f32(str_len * text_size) * text_align)

	dst_rect : SDL.Rect = { position.x, position.y, i32(text_size), i32(text_size) };
	clip     : SDL.Rect = { 0, 0, 8, 8 };

  for i in 0..<str_len {
		c := u8(text[i]);
		clip.x = i32((c % 16) * 8);
		clip.y = i32((c / 16) * 8);
		SDL.RenderCopy(renderer, small_text_texture.sdl_texture, &clip, &dst_rect);
		dst_rect.x += i32(text_size);
	}
	if do_ellipsis {
		c := '.';
		clip.x = i32((c % 16) * 8);
		clip.y = i32((c / 16) * 8);
		SDL.RenderCopy(renderer, small_text_texture.sdl_texture, &clip, &dst_rect);
		dst_rect.x += i32(text_size);
		SDL.RenderCopy(renderer, small_text_texture.sdl_texture, &clip, &dst_rect);
		dst_rect.x += i32(text_size);
	}
}

render_small_text_int :: proc(num, radix: int, position: Vec2i, max_len: int, text_align, scale: f32) {
  buffer : [32] u8
  text := strconv.itoa(buffer[:], num)
  render_small_text(text, position, max_len, text_align, scale)
}

render_small_text_float :: proc(num: f64, position: Vec2i, max_len: int, text_align, scale: f32) {
  buffer : [32] u8
  text := strconv.ftoa(buffer[:], num, 'f', 4, 64)
  render_small_text(text, position, max_len, text_align, scale)
}
