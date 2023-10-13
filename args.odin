package main

import "core:os"
import "core:log"

read_args :: proc(allocator:= context.allocator) -> (ArgsResult, bool) {
    context.allocator = allocator
    result : ArgsResult
    using result
    for arg in os.args[1:] {
        if arg == "-q" || arg == "--quiet" {
            quiet = true
        } else if arg == "-c" || arg == "--color" {
            color = true
        } else if arg == "-p" || arg == "--progress" {
            progress = true
        } else if arg == "-sli" || arg == "--sort-lines-inc" {// TODO
            sort_lines_inc = true
        } else if arg == "-sld" || arg == "--sort-lines-dec" {// TODO
            sort_lines_dec = true
        } else {
            if os.is_dir(arg) {
                if directory != "" {
                    log.errorf("ArgsError: You specified the root directory repeatly.")
                    args_result_release(&result)
                    return {}, false
                } else {
                    directory = arg
                }
            } else if os.is_file(arg) {
                append(&files, arg)
            } else {
                args_result_release(&result)
                return {}, false
            }
        }
    }

    if len(result.directory) > 0 && len(result.files) > 0 {
        log.errorf("ArgsError: You cannot specify files and a directory at the same time.")
        args_result_release(&result)
        return {}, false
    }
    
    return result, true
}

args_result_release :: proc(using result: ^ArgsResult) {
    if len(files) == 0 do delete(files)
}

args_result_apply :: proc(using result: ^ArgsResult, config: ^CodyConfig) {
    if result.quiet do config.quiet = true
    if result.color do config.color = true
    if result.progress do config.progress = true
}

ArgsResult :: struct {
    directory : string,
    files : [dynamic]string,
    quiet, color, progress : bool,
    sort_lines_inc, sort_lines_dec : bool,
}