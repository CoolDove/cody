package main

import "core:os"
import "core:io"
import "core:fmt"
import "core:thread"
import "core:strings"
import "core:unicode/utf8"
import "core:path/filepath"

extensions :[]string= {
    ".cs",
    ".cpp",
    ".h",
    ".shader",
    ".glsl",

    ".odin",
    ".jai",
}

CountContext :: struct {
    handles : [dynamic]os.Handle,
}

main :: proc() {
    if len(os.args) < 2 do return

    dir := os.args[1]

    ctx : CountContext

    ite(dir, &ctx)
    defer delete(ctx.handles)

    tasks := make([]TaskInfo, len(ctx.handles))

    thread_pool : thread.Pool
    thread.pool_init(&thread_pool, context.allocator, 8)
    thread.pool_start(&thread_pool)
    defer thread.pool_destroy(&thread_pool)

    for h, idx in ctx.handles {
        tasks[idx] = TaskInfo {
            ctx = &ctx,
            idx = cast(i64)idx,
            result = -1,
        }
        thread.pool_add_task(&thread_pool, context.allocator, task_count_file, &tasks[idx])
    }
    thread.pool_join(&thread_pool)
    thread.pool_finish(&thread_pool)
    total_lines := 0
    for h, idx in ctx.handles {
        fi, err_fi := os.fstat(h)
        lines := tasks[idx].result
        total_lines += auto_cast lines
        fmt.printf("{}: {}\n", fi.fullpath, lines)
        os.close(h)
    }
    fmt.printf("Total: {}\n", total_lines)
    
}

ite :: proc(path: string, ctx: ^CountContext) {
    if os.is_dir(path) {
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
        h, err := os.open(path)
        append(&ctx.handles, h)
    }
}

is_ext_match :: proc(extension : string) -> bool {
    for e in extensions do if extension == e do return true
    return false
}

task_count_file :: proc(task: thread.Task) {
    context.allocator = task.allocator
    info :^TaskInfo= cast(^TaskInfo)task.data
    using info
    h := ctx.handles[idx]

    lines :i64= 0
    data, read_success := os.read_entire_file_from_handle(h)
    if read_success {
        for b in data {
            if b == '\n' do lines+=1
        }
        delete(data)
        info.result = lines
    }
}

TaskInfo :: struct {
    ctx : ^CountContext,
    idx : i64,
    result : i64,
}