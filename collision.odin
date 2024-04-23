package main

import "core:fmt"
import SDL "vendor:sdl2"

aabb_frect :: proc(r1, r2 : SDL.FRect) -> bool {
  return !(r1.x        > r2.x + r2.w ||
           r1.x + r1.w < r2.x				 ||
           r1.y        > r2.y + r2.h ||
           r1.y + r1.h < r2.y        )
}

aabb_rect :: proc(r1, r2 : SDL.Rect) -> bool {
  return !(r1.x        > r2.x + r2.w ||
           r1.x + r1.w < r2.x				 ||
           r1.y        > r2.y + r2.h ||
           r1.y + r1.h < r2.y        )
}

// TODO: this should return -1 if there is no collision and 0 should be player already in collision at start of frame. no idea why id did it so unintuitively the first time around
swept_aabb_frect :: proc(r1 : SDL.FRect, v1 : Vector2, r2 : SDL.FRect, v2 : Vector2) -> (int, f32, Direction) {
	// check if rectangles are in collision at time == 0
	if (aabb_frect(r1, r2)) {
		return -1, 0, {}
	}

	// do broad phase collision check
	r1_broad : SDL.FRect = {
		x = v1.x > 0 ? r1.x : r1.x + v1.x,
		y = v1.y > 0 ? r1.y : r1.y + v1.y,
		w = v1.x > 0 ? v1.x + r1.w : r1.w - v1.x,
		h = v1.y > 0 ? v1.y + r1.h : r1.h - v1.y,
	}
	r2_broad : SDL.FRect = {
		x = v2.x > 0 ? r2.x : r2.x + v2.x,
		y = v2.y > 0 ? r2.y : r2.y + v2.y,
		w = v2.x > 0 ? v2.x + r2.w : r2.w - v2.x,
		h = v2.y > 0 ? v2.y + r2.h : r2.h - v2.y,
	}
	if (!aabb_frect(r1_broad, r2_broad)) {
		return 0, 0, {}
  }

	// get relative velocity
	v : Vector2 = v1 - v2

	// determine distance to collision entry and exit
	dEntry, dExit : Vector2
	if (v.x >= 0.0) {
		dEntry.x = r2.x - (r1.x + r1.w)
		dExit.x  = (r2.x + r2.w) - r1.x
	}
	else {
		dEntry.x = (r2.x + r2.w) - r1.x 
		dExit.x  = r2.x - (r1.x + r1.w)
	}

	if (v.y >= 0.0) {
		dEntry.y = r2.y - (r1.y + r1.h)
		dExit.y  = (r2.y + r2.h) - r1.y
	}
	else {
		dEntry.y = (r2.y + r2.h) - r1.y
		dExit.y  = r2.y - (r1.y + r1.h)
	}

	// determine time of entry and exit in each axis
	tEntry, tExit : Vector2

	tEntry.x = dEntry.x / v.x
	tExit.x  = dExit.x  / v.x

	tEntry.y = dEntry.y / v.y
	tExit.y  = dExit.y  / v.y

	// determine actual time of entry and exit
	entryTime, exitTime : f32
	entryTime = max(tEntry.x, tEntry.y)
	exitTime  = min(tExit.x,  tExit.y )

	// return false if no collision occurred
	if (entryTime > exitTime || (tEntry.x < 0.0 && tEntry.y < 0.0) || tEntry.x > 1.0 || tEntry.y > 1.0) {
		return 0, 0, {}
	}

  // direction : Directions = (DIR_R if dEntry.x > 0.0 else DIR_L) if tEntry.x > tEntry.y else (DIR_D if dEntry.y > 0.0 else DIR_U)
  // direction : Directions = tEntry.x > tEntry.y ? (dEntry.x > 0.0 ? DIR_R : DIR_L) : (dEntry.y > 0.0 ? DIR_D : DIR_U)
  direction : Direction
  if tEntry.x > tEntry.y {
    if dEntry.x > 0.0 do direction = .R 
    else              do direction = .L 
  }
  else {
    if dEntry.y > 0.0 do direction = .D 
    else              do direction = .U 
  }
	return 1, entryTime, direction
}

is_point_within_frect :: proc(point: Vector2, rect: SDL.FRect) -> bool {
	return point.x > rect.x && point.x < rect.x + rect.w &&
				 point.y > rect.y && point.y < rect.y + rect.h 
}

is_point_within_rect :: proc(point: Vec2i, rect: SDL.Rect) -> bool {
	return point.x > rect.x && point.x < rect.x + rect.w &&
				 point.y > rect.y && point.y < rect.y + rect.h 
}