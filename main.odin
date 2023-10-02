package main

import "core:os"
import "core:io"
import "core:fmt"
import "core:log"
import "core:thread"
import "core:strings"
import "core:math"
import "core:unicode/utf8"
import "core:path/filepath"
import "core:time"

import clc "./collection"
import ansi "./ansi_code"

TaskInfo :: struct {
    ctx : ^CodyContext,
    idx : i64,

    result : i64,
    comment : i64,
    code : i64,
    blank : i64,
}

main :: proc() {
    dir :string= os.get_current_directory()
    if len(os.args) == 1 {
        dir = os.get_current_directory()
    } else if len(os.args) == 2 {
        if os.args[1] == "help" {
            help()
            return
        }
        dir = os.args[1]
    } else {
        fmt.printf("Invalid args.")
        return
    }

    codyrc_init(); defer codyrc_release()
    codyrc_load(dir)
    // codyrc_debug()
    
    cody:= cody_create(math.clamp(config.task_page_size, 1, 1024)); defer cody_destroy(&cody)

    cody_begin(&cody, math.clamp(config.thread_count, 1, 64))
    if len(config.directories) == 0 {
        ite(dir, &cody)
    } else {
        for d in config.directories {
            ite(clc.pstr_to_string(d), &cody)
        }
    }
    cody_end(&cody)

    total_lines, total_lines_code, total_lines_blank, total_lines_comment := 0,0,0,0
    for h, idx in cody.handles {
        task := clc.pga_get_ptr(&cody.tasks, idx)
        total_lines += auto_cast task.result
        total_lines_code += auto_cast task.code
        total_lines_blank += auto_cast task.blank
        total_lines_comment += auto_cast task.comment

        if !config.quiet {
            fi, err_fi := os.fstat(h)
            fmt.printf("[\033[45m {} \033[49m]: {} codes, {} blanks, {} comments, {} total.\n",
                fi.fullpath,
                task.code, task.blank, task.comment, task.result)
        }
        os.close(h)
    }
    fmt.printf("Done\n")
    fmt.printf("Total time: {} s\n", time.duration_seconds(time.stopwatch_duration(cody.stopwatch)))
    fmt.printf("Total: {}, code lines: \033[4m{}\033[0m, blank lines: \033[4m{}\033[0m, comment lines: \033[4m{}\033[0m,\n", 
        total_lines, total_lines_code, total_lines_blank, total_lines_comment)
}

ite :: proc(path: string, ctx: ^CodyContext) {
    if os.is_dir(path) {
        if is_dir_ignored(path) do return 
        if dh, err_open := os.open(path); err_open == os.ERROR_NONE {
            defer os.close(dh)
            if fis, err_read_dir := os.read_dir(dh, -1); err_read_dir == os.ERROR_NONE {
                defer delete(fis)
                for fi in fis {
                    ite(fi.fullpath, ctx)
                }
            }
        }
    } else if is_ext_match(filepath.ext(path)) {
        if h, err := os.open(path); err == os.ERROR_NONE {
            append_task(ctx, h)
        }
        update(ctx)
    }
}

update :: proc(using cody: ^CodyContext) {
    ms := time.duration_seconds(time.stopwatch_duration(cody.stopwatch))
    if ms - cody.last_frame_time > 0.05 {
        using clc
        finished := 0
        idx : int
        for task in pga_ite(&cody.tasks, &idx) {
            if task.result != -1 do finished += 1
        }
        last_frame_time = ms
        ansi.show_cursor(false)
        ansi.store_cursor()
        ansi.erase(.FromCursorToEnd)
        fmt.printf("Progress: {}/{}", finished, pga_len(&cody.tasks))
        ansi.restore_cursor()
        ansi.show_cursor(true)
    }
}

append_task :: proc(cody: ^CodyContext, handle: os.Handle) {
    idx := len(cody.handles)
    append(&cody.handles, handle)
    task := clc.pga_append(&cody.tasks, TaskInfo {
        ctx = cody,
        idx = auto_cast idx,
        result = -1,
    })
    thread.pool_add_task(&cody.thread_pool, context.allocator, task_count_file, task)
}

is_ext_match :: proc(extension : string) -> bool {
    for ext_pstr in config.extensions {
        if extension == clc.pstr_to_string(ext_pstr) do return true
    }
    return false
}

is_dir_ignored :: proc(path: string) -> bool {
    if len(path) > 4 && path[len(path)-4:] == ".git" do return true
    if len(config.ignored_directories_fullpath) > 0 {
        if di, err := os.stat(path); err == os.ERROR_NONE {
            for ignore_dir in config.ignored_directories_fullpath {
                if ignore_dir == di.fullpath do return true
            }
        }
    }
    return false
}

task_count_file :: proc(task: thread.Task) {
    context.allocator = task.allocator
    info := cast(^TaskInfo)task.data
    using info
    h := ctx.handles[idx]

    lines :i64= 0
    data, read_success := os.read_entire_file_from_handle(h)
    if read_success {
        info.result = 0
        scan_text(transmute(string)data, info)
        delete(data)
    }
}