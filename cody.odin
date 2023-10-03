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

    file_buffers : [][]u8,
    // Indicates if the corresponding file buffer is not being used.
    file_buffers_using : []bool,

    stopwatch : time.Stopwatch,
    last_frame_time : f64,
}

cody_create :: proc(task_page_size: int=32, allocator:=context.allocator) -> CodyContext {
    cody:= CodyContext {
        handles = make([dynamic]os.Handle),
    }
    clc.pga_make(&cody.tasks, task_page_size)
    return cody
}

cody_begin :: proc(cody: ^CodyContext, thread_count := 8, thread_allocator:= context.allocator) {
    using thread, time
    pool_init(&cody.thread_pool, thread_allocator, thread_count)
    pool_start(&cody.thread_pool)
    stopwatch_start(&cody.stopwatch)
    cody.file_buffers = make([][]u8, thread_count)
    for i in 0..<thread_count {
        cody.file_buffers[i] = make([]u8, 4096)
    }
    cody.file_buffers_using = make([]bool, thread_count)
}
cody_end :: proc(cody: ^CodyContext) {
    using thread, time
    pool_join(&cody.thread_pool)
    pool_finish(&cody.thread_pool)
    stopwatch_stop(&cody.stopwatch)
    for fb in cody.file_buffers {
        delete(fb)
    }
    delete(cody.file_buffers)
    delete(cody.file_buffers_using)
    cody.file_buffers = {}
}

cody_destroy :: proc(cody: ^CodyContext) {
    clc.pga_delete(&cody.tasks)
    delete(cody.handles)
    thread.pool_destroy(&cody.thread_pool)
}