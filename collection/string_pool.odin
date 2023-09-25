package collection

import "core:fmt"
import "core:runtime"
import "core:strings"

StringPool :: struct {
    buffer: strings.Builder,
    pstrings: [dynamic]PString,
}

PString :: struct {
    pool: ^StringPool,
    start,end: int,
}

strp_make :: proc(allocator:= context.allocator) -> StringPool {
    context.allocator = allocator
    pool: StringPool
    strings.builder_init(&pool.buffer)
    pool.pstrings = make([dynamic]PString)
    return pool
}
strp_delete :: proc(pool: ^StringPool) {
    strings.builder_destroy(&pool.buffer)
    delete(pool.pstrings)
}
strp_append :: proc(pool: ^StringPool, text: string) -> PString {
    using strings
    start := builder_len(pool.buffer)
    write_string(&pool.buffer, text)
    end := builder_len(pool.buffer)
    pstr := PString{pool, start, end}
    append(&pool.pstrings, pstr)

    return pstr
}
pstr_to_string :: #force_inline proc(using pstr: PString) -> string {
    return strings.to_string(pool.buffer)[start:end]
}

// TODO