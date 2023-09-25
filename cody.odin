package main

import "core:os"
import "core:io"
import "core:fmt"
import "core:thread"
import "core:strings"
import "core:unicode/utf8"
import "core:path/filepath"
import "core:time"

import clc "./collection"


CodyContext :: struct {
    handles : [dynamic]os.Handle,
    tasks : clc.PageArray(TaskInfo),
    thread_pool : thread.Pool,
    stopwatch : time.Stopwatch,
    last_frame_time : f64,
}

cody_create :: proc(allocator:=context.allocator) -> CodyContext {
    cody:= CodyContext {
        handles = make([dynamic]os.Handle),
    }
    clc.pga_make(&cody.tasks, 32)
    return cody
}

cody_begin :: proc(cody: ^CodyContext, thread_allocator:= context.allocator) {
    using thread, time
    pool_init(&cody.thread_pool, thread_allocator, 8)
    pool_start(&cody.thread_pool)
    stopwatch_start(&cody.stopwatch)
}
cody_end :: proc(cody: ^CodyContext) {
    using thread, time
    pool_join(&cody.thread_pool)
    pool_finish(&cody.thread_pool)
    stopwatch_stop(&cody.stopwatch)
}

cody_destroy :: proc(cody: ^CodyContext) {
    clc.pga_delete(&cody.tasks)
    delete(cody.handles)
    thread.pool_destroy(&cody.thread_pool)
}