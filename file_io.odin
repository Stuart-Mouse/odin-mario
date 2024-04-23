package main

import "core:os"
import "core:fmt"
import "core:mem"
import "core:strconv"
import "core:strings"
import "shared:gon"

load_tile_info :: proc() -> bool {
    file, ok := os.read_entire_file("data/tiles.gon")
    if !ok {
      fmt.println("Unable to open tile info file!")
      return false
    }
    defer delete(file)
  
    clear(&tile_info_lookup)
    
    {
      empty_tile_ti : Tile_Info
      empty_tile_name := "Empty Tile"
      mem.copy(&empty_tile_ti.name, raw_data(empty_tile_name), len(empty_tile_name)) 
      append(&tile_info_lookup, empty_tile_ti)
    }
    
    parse_context := gon.SAX_Parse_Context {
        file = string(file),
        data_bindings = {
            { binding = tile_info_lookup, field_path = "tiles" },
        },
        event_handler = {
            // this is a bit crude, but it should work
            field_read = proc(ctxt: ^gon.SAX_Parse_Context, field: ^gon.SAX_Field) -> gon.SAX_Return_Code {
                if field.name == "frames" {
                    if field.parent.data_binding.id == typeid_of(Tile_Info) {
                        tile_info := cast(^Tile_Info) field.parent.data_binding.data
                        field.data_binding = tile_info.animation.frames
                    }
                }
                else if field.parent.name == "frames" {
                    if field.parent.parent.data_binding.id == typeid_of(Tile_Info) {
                        tile_info := cast(^Tile_Info) field.parent.parent.data_binding.data
                        if tile_info.animation.frame_count >= MAX_TILE_ANIM_FRAMES {
                            fmt.printf("Error: too many frames specified for tile %v\n", string(tile_info.name[:]))
                        }
                        tile_info.animation.frame_count += 1
                    }
                }
                return .OK
            },
            object_end = proc(ctxt: ^gon.SAX_Parse_Context, field: ^gon.SAX_Field) -> gon.SAX_Return_Code {
                if field.parent.name == "tiles" {
                    tile_info := cast(^Tile_Info) field.data_binding.data
                    fmt.println(string(tile_info.name[:]))
                }
                return .OK
            }
        },
    }
    
    if !gon.SAX_parse_file(&parse_context) {
        fmt.println("Unable to parse tile info!")
        return false
    }
    
    return true
}

save_tile_info :: proc() -> bool {
    sb := strings.builder_make()
    defer strings.builder_destroy(&sb)

    strings.write_string(&sb, "tiles [\n")
    
    for i in 1..<len(tile_info_lookup) {
        ti := &tile_info_lookup[i]
    
        // fmt.sbprintf(&sb, "%v {{\n")
        strings.write_string(&sb, "{\n")
        
        gon.serialize_any(&sb, "name", ti.name, indent = 2)
        gon.serialize_any(&sb, "collision", ti.collision, indent = 2)
        
        strings.write_string(&sb, "  frames [\n")
        for i in 0..<ti.animation.frame_count {
            frame := ti.animation.frames[i]
            fmt.sbprintf(&sb, "    [[ %v, %v ] %v ]\n", frame.clip_offset.x, frame.clip_offset.y, frame.duration)
        }
        strings.write_string(&sb, "  ]\n")
        
        strings.write_string(&sb, "}\n")
    }

    strings.write_string(&sb, "]\n")

    return os.write_entire_file("data/tiles.gon", sb.buf[:])
}
