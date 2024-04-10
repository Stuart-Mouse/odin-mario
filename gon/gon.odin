package gon

import "core:fmt"
import "core:strconv"

Token_Type :: enum {
  INVALID,
  STRING,
  OBJECT_BEGIN,
  OBJECT_END,
  ARRAY_BEGIN,
  ARRAY_END,
  EOF,
}

print_all_tokens :: proc(file: string) {
  file := file
  next_token_type : Token_Type
  next_token      : string
  fmt.println("Tokens in file:")
  for {
    next_token_type, next_token = get_next_token(&file)
    #partial switch next_token_type {
      case .INVALID:      fmt.println("INV"); return
      case .EOF:          fmt.println("EOF"); return
      case .OBJECT_BEGIN: fmt.println("{")
      case .OBJECT_END:   fmt.println("}")
      case .ARRAY_BEGIN:  fmt.println("[")
      case .ARRAY_END:    fmt.println("]")
      case: fmt.println(next_token)
    }
  }
  fmt.println()
}

// mutates the passed string, advancing it to the position after the returned token
get_next_token :: proc(file: ^string) -> (Token_Type, string) {
  if len(file^) <= 0 do return .EOF, ""
  if !skip_whitespace_and_comments(file) do return .EOF, ""
  if len(file^) <= 0 do return .EOF, ""

  switch file^[0] {
    case '{':
      advance(file)
      return .OBJECT_BEGIN, ""
    case '}':
      advance(file)
      return .OBJECT_END, ""
    case '[':
      advance(file)
      return .ARRAY_BEGIN, ""
    case ']':
      advance(file)
      return .ARRAY_END, ""
  }

  // next token is a string token
  string_value := file^

  // scan for end of string in quotation marks
  if file^[0] == '\"' {
    if !advance(file) do return .INVALID, ""
    string_value = string_value[1:]
    string_len := 0

    for file^[0] != '\"' {
      adv : int = 1
      if file^[0] == '\\' do adv = 2
      if !advance(file, adv) do return .INVALID, ""
      string_len += adv
    }

    if !advance(file) do return .INVALID, ""

    return .STRING, string_value[:string_len]
  }

  // scan for end of bare string
  if !is_reserved_char(file^[0]) {
    string_len := 0
    for !is_reserved_char(file^[0]) && !is_whitespace(file^[0]) {
      if !advance(file) {
        return .EOF, ""
      }
      string_len += 1
    }
    return .STRING, string_value[:string_len]
  }

  // there's probably some funky character in the file...?
  fmt.println("Something funky happened.\n")
  return .INVALID, ""
}

// bascially wraps our slice operation so that we can handle an error in the case that we run out of characters
advance :: proc(file: ^string, amount := 1) -> bool {
  amount := min(amount, len(file))
  file^ = file^[amount:]
  return len(file) != 0 
}

is_whitespace :: proc(char: u8) -> bool {
  return char == ' ' || char == ',' || char == '\t' || char == '\r' || char == '\n'
}

is_reserved_char :: proc(char: u8) -> bool {
  return char == '#' || char == '{' || char == '}' || char == '[' || char == ']'
}

skip_whitespace_and_comments :: proc(file: ^string) -> bool {
  for {
    for is_whitespace(file^[0]) {
      advance(file) or_return
    }
    if file^[0] == '#' {
      for file^[0] != '\n' {
        advance(file) or_return
      }
      continue
    }
    return true
  }
}

// do the basic in-situ parsing thing
File :: struct {
  fields : [dynamic] Field,
}

Field_Type :: enum { 
  INVALID = 0, 
  FIELD   = 1,
  OBJECT  = 2, 
  ARRAY   = 3,
}

Field :: struct {
  parent   : int,
  name     : string, 
  type     : Field_Type,
  value    : string,
  children : [dynamic] int
}

parse_file :: proc(str: string) -> (File, bool) {
  str := str
  using gon_file : File
  root : Field = { 
    parent = 0, 
    name   = "root",
    type   = .OBJECT,
  }
  append(&fields, root)
  if !parse_object(&gon_file, 0, &str) {
    destroy_file(&gon_file)
    return {}, false
  }
  return gon_file, true
}

parse_object :: proc(gon_file: ^File, parent: int, str: ^string) -> bool {
  using gon_file

  next_token_type : Token_Type
  next_token      : string

  for {
    field : Field
    field.parent = parent
    field_index := len(fields)

    // read field name
    if fields[parent].type != .ARRAY {
      next_token_type, next_token = get_next_token(str)
      #partial switch next_token_type {
        case .EOF:
          return true
        case .STRING:
          field.name = next_token
        case .OBJECT_END:
          if fields[parent].type != .OBJECT {
            fmt.printf("GON parse error: Unexpected %v token \"%v\".\n", next_token_type, next_token)
            return false
          }
          return true
        case:
          fmt.printf("GON parse error: Unexpected %v token \"%v\".\n", next_token_type, next_token)
          return false
      }
    }

    // read field value and append
    next_token_type, next_token = get_next_token(str)
    #partial switch next_token_type {
      case .STRING:
        field.type  = .FIELD
        field.value = next_token
      case .OBJECT_BEGIN:
        field.type = .OBJECT
      case .ARRAY_BEGIN:
        field.type = .ARRAY
      case .ARRAY_END:
        if fields[parent].type != .ARRAY {
          fmt.printf("GON parse error: Unexpected %v token \"%v\".\n", next_token_type, next_token);
          return false
        }
        return true
      case:
        fmt.printf("GON parse error: Unexpected %v token \"%v\".\n", next_token_type, next_token);
        return false
    }

    append(&fields, field)
    append(&fields[parent].children, field_index)
    if field.type == .OBJECT || field.type == .ARRAY {
      parse_object(gon_file, field_index, str) or_return
    }
  }
}

destroy_file :: proc(using file: ^File) {
  for &f in fields {
    destroy_field(&f)
  }
  delete(fields)
}

destroy_field :: proc(using field: ^Field) {
  delete(children)
}

get_child_by_name :: proc(using gon_file: ^File, parent: int, name: string) -> (int, bool) {
  if gon_file == nil || parent < 0 || parent >= len(fields) || fields[parent].type == .FIELD {
    return 0, false
  }
  for i in fields[parent].children {
    if fields[i].name == name {
      return i, true
    }
  }
  return 0, false
}

// searches the file an arbitrary depth and pulls out an index to the desired field
get_field_by_address :: proc(using gon_file: ^File, address: []string) -> (int, bool) {
  if gon_file == nil do return 0, false
  addr_idx : int
  parent   : int
  child    : int
  found    : bool
  for {
    fmt.println(".")
    fmt.println("parent is", parent, fields[parent])
    fmt.println("searching for", address[addr_idx])
    #partial switch fields[parent].type {
      case .FIELD:
        fmt.println("Parent type cannot be a field.")
        return 0, false
      case .OBJECT:
        fmt.println("o", addr_idx)
        child, found = get_child_by_name(gon_file, parent, address[addr_idx])
        if !found {
          fmt.println("No field found at address ", address[:addr_idx])
          return 0, false
        }
        fmt.println("found", address[addr_idx], "at", address[:addr_idx])
      case .ARRAY:
        fmt.println("a", addr_idx)
        index := strconv.atoi(address[addr_idx])
        if index < 0 || index >= len(fields[parent].children){
          fmt.println("Invalid index", index, "into", address[:addr_idx])
          return 0, false
        }
        fmt.println("found", address[addr_idx], "at", address[:addr_idx])
        child = fields[parent].children[index]
    }
    addr_idx += 1
    if addr_idx == len(address) {
      return child, true
    }
    parent = child
  }
  return 0, false
}

get_value_or_default :: proc(using gon_file: ^File, parent: int, name: string, default: string) -> string {
  child, ok := get_child_by_name(gon_file, parent, name)
  if !ok || fields[child].type != .FIELD do return default
  return fields[child].value
}

get_int_or_default :: proc(using gon_file: ^File, parent: int, name: string, default: int) -> int {
  child, ok := get_child_by_name(gon_file, parent, name)
  if !ok || fields[child].type != .FIELD do return default
  return strconv.atoi(fields[child].value)
}

get_float_or_default :: proc(using gon_file: ^File, parent: int, name: string, default: f64) -> f64 {
  child, ok := get_child_by_name(gon_file, parent, name)
  if !ok || fields[child].type != .FIELD do return default
  return strconv.atof(fields[child].value)
}

try_get_value :: proc(using gon_file: ^File, parent: int, name: string) -> (string, bool) {
  child, ok := get_child_by_name(gon_file, parent, name)
  if !ok || fields[child].type != .FIELD do return {}, false
  return fields[child].value, true
}

try_get_int :: proc(using gon_file: ^File, parent: int, name: string) -> (int, bool) {
  child, ok := get_child_by_name(gon_file, parent, name)
  if !ok || fields[child].type != .FIELD do return 0, false
  return strconv.atoi(fields[child].value), true
}

try_get_float :: proc(using gon_file: ^File, parent: int, name: string) -> (f64, bool) {
  child, ok := get_child_by_name(gon_file, parent, name)
  if !ok || fields[child].type != .FIELD  do return 0, false
  return strconv.atof(fields[child].value), true
}
