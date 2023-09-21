package main

import "core:os"
import "core:io"
import "core:fmt"
import "core:thread"
import "core:strings"
import "core:unicode/utf8"
import "core:path/filepath"
import "core:time"

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
    tasks : [dynamic]^TaskInfo,
    thread_pool : ^thread.Pool,
    stopwatch : ^time.Stopwatch,
    last_frame_time : f64,
}

TaskInfo :: struct {
    ctx : ^CountContext,
    idx : i64,
    result : i64,
}

main :: proc() {
    if len(os.args) < 2 do return

    dir := os.args[1]

    thread_pool : thread.Pool
    thread.pool_init(&thread_pool, context.allocator, 8)

    framewatch : time.Stopwatch

    ctx :CountContext= {
        make([dynamic]os.Handle),
        make([dynamic]^TaskInfo),
        &thread_pool,
        &framewatch,
        0.0,
    }
    
    defer {
        for t in ctx.tasks do free(t)
        delete(ctx.tasks)
        delete(ctx.handles)
        thread.pool_destroy(ctx.thread_pool)
    }

    thread.pool_start(ctx.thread_pool)
    time.stopwatch_start(ctx.stopwatch)

    ite(dir, &ctx)

    fmt.printf("Total time: {} s\n", time.duration_seconds(time.stopwatch_duration(framewatch)))

    thread.pool_join(&thread_pool)
    thread.pool_finish(&thread_pool)

    total_lines := 0
    for h, idx in ctx.handles {
        fi, err_fi := os.fstat(h)
        lines := ctx.tasks[idx].result
        total_lines += auto_cast lines
        // fmt.printf("{}: {}\n", fi.fullpath, lines)
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
        if h, err := os.open(path); err == os.ERROR_NONE {
            append_task(ctx, h)
        }
        update(ctx)
    }
}

update :: proc(using ctx: ^CountContext) {
    ms := time.duration_seconds(time.stopwatch_duration(ctx.stopwatch^))
    if ms - ctx.last_frame_time > 0.01 {
        finished := 0
        for task, idx in tasks {
            if task.result != -1 do finished += 1
        }
        last_frame_time = ms
        fmt.printf("Progress: {}/{}\n", finished, len(tasks))
    }
}

append_task :: proc(ctx: ^CountContext, handle: os.Handle) {
    idx := len(ctx.handles)
    append(&ctx.handles, handle)
    task := new(TaskInfo) 
    task^ = TaskInfo {
        ctx = ctx,
        idx = auto_cast idx,
        result = -1,
    }
    append(&ctx.tasks, task)
    thread.pool_add_task(ctx.thread_pool, context.allocator, task_count_file, task)
}

is_ext_match :: proc(extension : string) -> bool {
    for e in extensions do if extension == e do return true
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
        for b in data {
            if b == '\n' do lines+=1
        }
        delete(data)
        info.result = lines
    }
}
// Timer
Timer :: struct {
    stopwatch : time.Stopwatch,
}
timer_begin :: proc() -> Timer {
    w : time.Stopwatch
    time.stopwatch_start(&w)
    return Timer {w}
}
timer_end :: proc(timer: ^Timer) -> f64 {
    time.stopwatch_stop(&timer.stopwatch)
    return time.duration_seconds(time.stopwatch_duration(timer.stopwatch))
}