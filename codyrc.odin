package main

import "core:runtime"
import "core:os"
import "core:strings"
import "core:slice"
import "core:fmt"
import "core:path/filepath"
import "core:text/match"
import "core:strconv"
import clc "./collection"

CodyConfig :: struct {
    // ##Basic
    quiet: bool,
    output: string,
    directories: [dynamic]string,
    extensions: [dynamic]string,

    // ##Performance
    thread_count: int,
    task_page_size : int,

    // ##Other
    _str_pool : clc.StringPool,// Store all the string's copy used in the CodyConfig
}

config: CodyConfig

codyrc_init :: proc() {
    using config
    directories = make([dynamic]string)
    extensions = make([dynamic]string)
    _str_pool = clc.strp_make()   
    
    append(&extensions,
        ".c", ".cpp", ".h",
        ".shader", ".glsl", ".hlsl",
        ".cs",
        
        ".odin", ".jai", ".zig",
    )
    thread_count = 8
    task_page_size = 32
}

codyrc_release :: proc() {
    using config
    delete(directories)
    delete(extensions)
    clc.strp_delete(&_str_pool)
}

@(private="file")
_codyrc_append_directory :: proc(directories: ..string) {
    for dir in directories {
        append(&config.directories, clc.strp_append(&config._str_pool, dir))
    }
}
@(private="file")
_codyrc_apply_extensions :: proc(extensions: ..string) {
    clear(&config.extensions)
    for ext in extensions {
        append(&config.extensions, clc.strp_append(&config._str_pool, ext))
    }
}
@(private="file")
_codyrc_apply_output :: proc(output: string) {
    config.output = clc.strp_append(&config._str_pool, output)
}

codyrc_load :: proc(dir: string) -> bool {
    rcpath := filepath.join([]string{dir, ".codyrc"}); defer delete(rcpath)
    fmt.printf("RCPath: {}\n", rcpath)
    if source, ok := os.read_entire_file(rcpath); ok {
        defer delete(source)
        using strings
        text := transmute(string)source
        match_state : match.Match_State
        value_buffer := make([dynamic]ConfigValue); defer delete(value_buffer)
        for line in split_lines_iterator(&text) {
            key, value, ok := _codyrc_parse_line(line, &match_state)
            if ok {
                v, value_parse_ok := _codyrc_parse_value(value, &value_buffer)
                defer _codyrc_config_value_destroy(&v)
                if value_parse_ok {
                    if codyrc_set_value(key, v) {
                        fmt.printf("*{}: {}\n", key, v)
                    } else {
                        fmt.printf("!Failed to set {} : {}\n", key, v)
                    }
                } else {
                    fmt.printf("!Failed to parse {} : {}\n", key, value)
                }
            } else {
                return false
            }
        }
    } else {
        return false
    }
    return true
}

codyrc_set_value :: proc(key: string, value: ConfigValue) -> bool {
    using clc
    if key == "quiet" {
        if quiet, ok := value.(bool); ok {
            config.quiet = quiet
            return true
        } else do return false
    } else if key == "output" {
        if output, ok := value.(string); ok {
            config.output = strp_append(&config._str_pool, output)
            return true
        } else do return false
    } else if key == "directories" {
        return set_strings(&config.directories, value)
    } else if key == "extensions" {
        return set_strings(&config.extensions, value)
    } else if key == "thread_count" {
        if thread_count, ok := value.(f64); ok {
            config.thread_count = cast(int)thread_count
            return true
        } else do return false
    } else if key == "task_page_size" {
        if task_page_size, ok := value.(f64); ok {
            config.task_page_size = cast(int)task_page_size
            return true
        } else do return false
    } else {
        return false
    }
    return false

    set_strings :: proc(buffer: ^[dynamic]string, value: ConfigValue) -> bool {
        if single_string, ok := value.(string); ok {
            clear(buffer)
            append(buffer, strp_append(&config._str_pool, single_string))
            return true
        } else if multiple_strings, ok := value.([]ConfigValue); ok {
            for elem in multiple_strings {// Typecheck
                if _, ok := elem.(string); !ok do return false
            }
            clear(buffer)
            for str in multiple_strings {
                append(buffer, strp_append(&config._str_pool, str.(string)))
            }
            return true
        }
        return false
    }
}




@(private="file")
_codyrc_parse_line :: proc(line: string, match_state : ^match.Match_State) -> (string, string, bool) {
    match_state^ = {}
    match_state.pattern = "%s*([%w_]+)%s*:%s*(.*)%s*$"
    match_state.src = line
    unused, _ := match.match(match_state, 0,0)
    if unused != -1 {
        capture_key:= &match_state.capture[0]
        capture_value:= &match_state.capture[1]
        if capture_key.len > 0 && capture_value.len > 0 {
            key := _captured_string(capture_key, line)
            value := _captured_string(capture_value, line)
            return key, value, true
        }
    }
    return {},{}, false
}

@(private="file")
_codyrc_parse_value :: proc(raw_value: string, buffer: ^[dynamic]ConfigValue, allocator:= context.allocator) -> (ConfigValue, bool) {
    context.allocator = allocator
    clear(buffer)
    ptr := 0
    need_a_comma := false
    for ptr < len(raw_value) {
        if ok, consumed, value := _codyrc_parse_string(raw_value[ptr:]); ok {
            ptr += consumed
            append(buffer, value)
            need_a_comma = true
        } else if ok, consumed, value := _codyrc_parse_boolean(raw_value[ptr:]); ok {
            ptr += consumed
            append(buffer, value)
            need_a_comma = true
        } else if ok, consumed, value := _codyrc_parse_number(raw_value[ptr:]); ok {
            ptr += consumed
            append(buffer, value)
            need_a_comma = true
        } else {
            r := cast(rune)raw_value[ptr]
            if !match.is_space(r) {
                if r == ',' {
                    if need_a_comma {
                        need_a_comma = false
                    } else {
                        return nil, false
                    }
                } else {
                    return nil, false
                }
            }
            ptr += 1
        }
    }
    count := len(buffer)
    if count == 0 do return nil, false
    if count == 1 do return buffer[0], true
    else do return slice.clone(buffer[:]), true
}

@(private="file")
_codyrc_parse_string :: proc(source: string) -> (ok: bool, consumed: int, value: ConfigValue) {
    if len(source) <= 1 do return false, 0, nil
    for r, idx in source {
        if idx == 0 {
            if r != '\"' do return false, 0, value
        } else {
            if r == '\"' do return true, idx+1, source[1:idx]
        }
    }
    return false, 0, nil
}
@(private="file")
_codyrc_parse_boolean :: proc(source: string) -> (ok: bool, consumed: int, value: ConfigValue) {
    if false_ok, false_consumed := _codyrc_parse_literal(source, "false"); false_ok {
        return true, false_consumed, false
    } else if true_ok, true_consumed := _codyrc_parse_literal(source, "true"); true_ok {
        return true, true_consumed, true
    }
    return false, 0, nil
}
@(private="file")
_codyrc_parse_number :: proc(source: string) -> (ok: bool, consumed: int, value: ConfigValue) {
    v, nr, okk := strconv.parse_f64_prefix(source)
    if okk do return true, nr, v
    else do return false, 0, nil
}
@(private="file")
_codyrc_parse_literal :: proc(source: string, literal: string) -> (ok: bool, consumed: int) {
    if len(source) < len(literal) do return false, 0
    for r, idx in literal {
        if r != cast(rune)source[idx] {
            return false, 0
        }
    }
    return true, len(literal)
}


@(private="file")
_codyrc_config_value_destroy :: proc(value: ^ConfigValue) {
    // Only arrays need to be destroied now.
    #partial switch v in value {
    case []ConfigValue:
        for &d in v do _codyrc_config_value_destroy(&d)
        delete(v)
    }
}

@(private="file")
_captured_string :: #force_inline proc(capture: ^match.Capture, source: string) -> string {
    if capture.len < 0 do return {}
    return source[capture.init:capture.init+capture.len]
}

ConfigValue :: union {
    bool,
    f64,
    string,
    []ConfigValue,
}