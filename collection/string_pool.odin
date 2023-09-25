package collection


import "core:fmt"
import "core:runtime"
import "core:strings"

StringPool :: struct {
    buffer: strings.Builder,
    strs : [dynamic]string,
}

strp_make :: proc(allocator:= context.allocator) -> StringPool {
    context.allocator = allocator
    pool: StringPool
    strings.builder_init(&pool.buffer)
    pool.strs = make([dynamic]string)
    return pool
}
strp_delete :: proc(pool: ^StringPool) {
    strings.builder_destroy(&pool.buffer)
    delete(pool.strs)
}
strp_append :: proc(pool: ^StringPool, text: string) -> string {
    using strings
    start := builder_len(pool.buffer)
    write_string(&pool.buffer, text)
    end := builder_len(pool.buffer)
    str := to_string(pool.buffer)[start:end]
    append(&pool.strs, str)

    return str
}

// TODO