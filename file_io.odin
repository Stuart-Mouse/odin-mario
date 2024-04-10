package main

import "core:os"
import "core:fmt"
import "core:mem"
import "core:strconv"
import "gon"

load_tile_info :: proc() -> bool {
  file, ok := os.read_entire_file("data/tiles.gon")
  if !ok {
    fmt.println("Unable to open tile info file!")
    return false
  }
  defer delete(file)

  gon_file : gon.File
  gon_file, ok = gon.parse_file(string(file))
  if !ok {
    fmt.println("Unable to parse gon!")
    return false
  }
  defer gon.destroy_file(&gon_file)

  using gon_file

  clear(&tile_info_lookup)
  {
    empty_tile_ti : Tile_Info
    empty_tile_name := "Emtpy Tile"
    mem.copy(&empty_tile_ti.name, raw_data(empty_tile_name), len(empty_tile_name)) 
    append(&tile_info_lookup, empty_tile_ti)
  }

  for gon_tile_i in fields[0].children {
    gon_tile := fields[gon_tile_i]
    
    ti : Tile_Info
    mem.copy(
      raw_data(ti.name[:]), 
      raw_data(gon_tile.name), 
      min(31, len(gon_tile.name)),
    )

    // set collision value
    if gon_collision_flags_i, ok := gon.get_child_by_name(&gon_file, gon_tile_i, "collision_flags"); ok {
      gon_collision_flags := fields[gon_collision_flags_i]
      for field_i in gon_collision_flags.children {
        gon_flag := fields[field_i]
        if gon_flag.type != .FIELD {
          fmt.println("Error: Invalid flag in collision_flags.")
          return false
        }
        switch gon_flag.value {
          case "SOLID"    : ti.collision.flags |= { .SOLID     }
          case "BREAKABLE": ti.collision.flags |= { .BREAKABLE }
          case "BUMPABLE" : ti.collision.flags |= { .BUMPABLE  }
          case "CONTAINER": ti.collision.flags |= { .CONTAINER }
        }
      }
    }

    /*
      For now, "next" is the only option.
      If we want to specify the tiles by name and have that work, 
        then all tiles need to be loaded first before we can resolve 
        the tile ids by name.
    */
    if become_on_use, ok := gon.try_get_value(&gon_file, gon_tile_i, "become_on_use"); ok {
      if become_on_use == "next" {
        ti.become_on_use = u32(len(tile_info_lookup) + 1)
      } 
    } 

    ReadFrames: {
      gon_frames_i, ok := gon.get_child_by_name(&gon_file, gon_tile_i, "frames")
      gon_frames := fields[gon_frames_i]
      if !ok || gon_frames.type != .ARRAY {
        fmt.println("Error: Frames array was missing or wrong type.")
        return false
      }
      ti.animation.frame_count = len(gon_frames.children)

      for field_i, frame_i in gon_frames.children {
        gon_frame := fields[field_i]
        if gon_frame.type != .ARRAY {
          fmt.println("Error: Invalid frame in frames.")
          return false
        }

        switch len(gon_frame.children) {
          case 3:
            ti.animation.frames[frame_i].duration = int(strconv.atof(gon_file.fields[gon_frame.children[2]].value) * 60.0)
            fallthrough
          case 2:
            ti.animation.frames[frame_i].clip_offset.x = cast(i32)strconv.atoi(gon_file.fields[gon_frame.children[0]].value)
            ti.animation.frames[frame_i].clip_offset.y = cast(i32)strconv.atoi(gon_file.fields[gon_frame.children[1]].value)
          case:
            fmt.println("Error: Invalid frame in frames.")
            return false
        }
      }
    }

    append(&tile_info_lookup, ti)
  }
  
  return true
}
