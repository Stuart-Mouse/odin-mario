package main

import sdl "vendor:sdl2"
import "core:math/rand"
import "core:math"
import "core:fmt"
import "core:runtime"

Vec2i   :: [2] i32
Vector2 :: [2] f32
Vector3 :: [3] f32
Color4  :: [4] f32

Directions :: bit_set[Direction; u8]
Direction :: enum u8 {
	U  = 0,
	D  = 1,
	L  = 2,
	R  = 3,
	UR = 4,
	DR = 5,
	DL = 6,
	UL = 7,
}

AllDirections     : Directions : { .U, .D, .L, .R, .UR, .DR, .DL, .UL }
PrimaryDirections : Directions : { .U, .D, .L, .R }

direction_vectors : [Direction] Vector2 = {
	.U  = {  0, -1 },
	.D  = {  0,  1 },
	.L  = { -1,  0 },
	.R  = {  1,  0 },
	.UR = { -1,  1 },
	.DR = {  1,  1 },
	.UL = { -1, -1 },
	.DL = {  1, -1 },
}

sdl_frect_to_rect :: proc (frect: sdl.FRect) -> sdl.Rect {
	return {
		x = i32(frect.x),
		y = i32(frect.y),
		w = i32(frect.w),
		h = i32(frect.h),
	}
}

sdl_rect_to_frect :: proc (frect: sdl.Rect) -> sdl.FRect {
	return {
		x = f32(frect.x),
		y = f32(frect.y),
		w = f32(frect.w),
		h = f32(frect.h),
	}
}

sdl_frect_scale :: proc(frect: sdl.FRect, scale: f32) -> sdl.FRect {
	return {
		x = frect.x * scale,
		y = frect.y * scale,
		w = frect.w * scale,
		h = frect.h * scale,
	}
}

Weighted_Choice :: struct {
  value  : int,
  weight : int,
}
get_weighted_choice :: proc(choices: [] Weighted_Choice) -> int {
  sum := 0
  for choice in choices {
    sum += choice.weight
  }
  num := int(rand.int63_max(i64(sum)))
  for choice in choices {
    if num < choice.weight do return choice.value
    num -= choice.weight
  }
  return choices[len(choices)-1].value
}

distance_between_points :: proc(p1, p2: Vector2) -> f32 {
  dx := p1.x - p2.x
  dy := p1.y - p2.y
  return math.sqrt((dx * dx) + (dy * dy))
}

lerp :: proc(a, b, lerp: f32) -> f32 {
  high := max(a, b)
  low  := min(a, b)
  return lerp * (high - low) + low
}

delerp :: proc(a, b, val: f32) -> f32 {
  high := max(a, b)
  low  := min(a, b)
  return (val - low) / (high - low)
}

pixel_to_internal_units :: proc(pixel_position: Vec2i, internal_unit: f32, pixel_offset := Vec2i {}, internal_offset := Vector2 {}) -> Vector2 {
	return Vector2 {
		f32(pixel_position.x - pixel_offset.x) / internal_unit + internal_offset.x,
		f32(pixel_position.y - pixel_offset.y) / internal_unit + internal_offset.y,
	}
}

// returns -1 if index is not in valid range
get_grid_index_checked :: proc(position, tile_size : Vector2, grid_size: Vec2i, offset := Vector2 {}, margin := Vector2 {}) -> int {
	pos := position - offset + (margin / 2)
	index_2D := Vec2i {
		i32(pos.x / (tile_size.x + margin.x)),
		i32(pos.y / (tile_size.y + margin.y)),
	}
	if index_2D.x < 0 || index_2D.x >= grid_size.x ||
		 index_2D.y < 0 || index_2D.y >= grid_size.y {
		return -1
	}
	return int(index_2D.y * grid_size.x + index_2D.x)
}

get_grid_tile_rect :: proc(index: int, tile_size : Vector2, grid_size: Vec2i, offset := Vector2 {}, margin := Vector2 {}) -> sdl.FRect {
	index_2D : Vec2i = {
		i32(index) % grid_size.x,
		i32(index) / grid_size.x,
	}
	rect : sdl.FRect = {
		x = (tile_size.x + margin.x) * (f32(index_2D.x) + offset.x) - (margin.x / 2),
		y = (tile_size.y + margin.y) * (f32(index_2D.y) + offset.y) - (margin.y / 2),
		w = (tile_size.x + margin.x),
		h = (tile_size.y + margin.y),
	}
	if index_2D.x < 0 || index_2D.x >= grid_size.x ||
	   index_2D.y < 0 || index_2D.y >= grid_size.y {
		return {}
	}
	return rect
}

frect_to_rect :: proc(frect: sdl.FRect) -> sdl.Rect {
	return sdl.Rect {
		i32(math.floor(frect.x)),
		i32(math.floor(frect.y)),
		i32(math.floor(frect.w)),
		i32(math.floor(frect.h)),
	}
}

rect_to_frect :: proc(rect: sdl.Rect) -> sdl.FRect {
	return sdl.FRect {
		f32(rect.x),
		f32(rect.y),
		f32(rect.w),
		f32(rect.h),
	}
}

SlotArray :: struct($T: typeid, $N: int) {
	slots   : [N] Slot(T),
	current : int,
}

Slot :: struct($T: typeid) {
	occupied : bool,
	data     : T,
}

get_next_empty_slot :: proc(using arr: ^SlotArray($T, $N)) -> ^Slot(T) {
  for &slot in slots {
		if !slot.occupied {
			return &slot
		}
	}
	return nil
}

get_next_slot :: proc(arr: ^SlotArray($T, $N)) -> ^Slot(T) {
  arr.current = (arr.current + 1) % len(arr.slots)
  return &arr.slots[arr.current]
}

snap_to_nearest_unit :: proc(point: f32, unit: f32) -> f32 {
  point_in_units       := point / unit
  point_in_units_floor := math.floor(point_in_units)
  if point_in_units - point_in_units_floor < 0.5 {
    return point_in_units_floor * unit;
	}
	return (point_in_units_floor + 1.0) * unit
}
