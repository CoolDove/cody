package main

import "core:runtime"
import "core:os"
import "core:strings"
import "core:log"
import "core:slice"
import "core:fmt"
import "core:path/filepath"
import "core:text/match"
import "core:strconv"

import ansi "./ansi_code"
import clc "./collection"

CodyConfig :: struct {
    // ##Basic
    output: clc.PString,
    directories: [dynamic]clc.PString,
    ignore_directories: [dynamic]clc.PString,
    extensions: [dynamic]clc.PString,

    // ##Output
    progress : bool,
    quiet, color: bool,

    // ##Performance
    thread_count: int,
    task_page_size : int,

    // ##Other
    _str_pool : clc.StringPool,// Store all the string's copy used in the CodyConfig
    ignored_directories_fullpath : []string,
}
ConfigValue :: union {
    bool,
    f64,
    string,
    []ConfigValue,
}

config: CodyConfig

codyrc_init :: proc() {
    using config, clc
    directories = make([dynamic]clc.PString)
    ignore_directories = make([dynamic]clc.PString)
    extensions = make([dynamic]clc.PString)
    _str_pool = strp_make()   


    default_extensions : []string= {
        ".c", ".cpp", ".h",
        ".shader", ".glsl", ".hlsl",
        ".cs",
        
        ".odin", ".jai", ".zig",
    }

    for ext in default_extensions do append(&extensions, strp_append(&_str_pool, ext))
    
    thread_count = 8
    task_page_size = 32
}

codyrc_release :: proc() {
    using config
    delete(directories)
    delete(ignore_directories)
    delete(extensions)
    if len(ignored_directories_fullpath) != 0 do delete(ignored_directories_fullpath)
    clc.strp_delete(&_str_pool)
}

codyrc_load :: proc(dir: string) -> bool {
    rcpath := filepath.join([]string{dir, ".codyrc"}); defer delete(rcpath)
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
                    if !codyrc_set_value(key, v) {
                        ansi.color(.Red)
                        fmt.printf("!Failed to set {} : {}\n", key, v)
                        ansi.color(.Default)
                    }
                } else {
                    ansi.color(.Red)
                    fmt.printf("!Failed to parse {} : {}\n", key, value)
                    ansi.color(.Default)
                }
            } else {
                ansi.color(.Red)
                fmt.printf("!Failed to parse {}\n", line)
                ansi.color(.Default)
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
    } else if key == "color" {
        if color, ok := value.(bool); ok {
            config.color = color
            return true
        } else do return false
    } else if key == "progress" {
        if progress, ok := value.(bool); ok {
            config.progress = progress
            return true
        } else do return false
    } else if key == "output" {
        if output, ok := value.(string); ok {
            config.output = strp_append(&config._str_pool, output)
            return true
        } else do return false
    } else if key == "directories" {
        return set_strings(&config.directories, value)
    } else if key == "ignore_directories" {
        if set_strings(&config.ignore_directories, value) {
            codyrc_bake_ignored_dirs()
            return true
        }
        return false
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

    set_strings :: proc(buffer: ^[dynamic]clc.PString, value: ConfigValue) -> bool {
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
codyrc_bake_ignored_dirs :: proc() {
    if len(config.ignored_directories_fullpath) != 0 {
        delete(config.ignored_directories_fullpath)
        config.ignored_directories_fullpath = {}
    }
    
    if len(config.ignore_directories) == 0 do return
    dirs := make([dynamic]string, 0, len(config.ignore_directories)) ; defer delete(dirs)
    for dir in config.ignore_directories {
        fi, err := os.stat(clc.pstr_to_string(dir))
        if err == os.ERROR_NONE {
            append(&dirs, fi.fullpath)
        }
    }
    config.ignored_directories_fullpath = slice.clone(dirs[:])
}


codyrc_debug :: proc() {
    using strings, clc
    // log.debugf("Codyrc: {}", )
    log.debugf("Codyrc debug:")
    fmt.printf("directories: \n")
    for d in config.directories {
        fmt.printf("> {}\n", pstr_to_string(d))
    }
    fmt.printf("extensions: \n")
    for d in config.extensions {
        fmt.printf("> {}\n", pstr_to_string(d))
    }
    fmt.printf("ignored directories: \n")
    for d in config.ignored_directories_fullpath {
        fmt.printf("> {}\n", d)
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