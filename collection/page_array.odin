package collection

import "core:runtime"

PageArray :: struct($T:typeid) {
    pages : [dynamic][]T,
    page_size : int,
    length : int,
    page_allocator : runtime.Allocator,
}

pga_make :: proc(pga: ^PageArray($T), page_size: int, reserve_pages: int=1, allocator:= context.allocator) -> bool {
    if page_size <= 0 || reserve_pages <= 0 do return false
    pga.page_size = page_size
    pga.page_allocator = allocator
    _pga_append_page(pga)
    return true
}
pga_delete :: proc(using pga: ^PageArray($T)) {
    context.allocator = page_allocator
    for page in pages do delete(page)
    delete(pages)
}
pga_append :: proc(using pga: ^PageArray($T), elem: T) {
    page_id := length/page_size
    idx := length%page_size
    if page_id == len(pages) - 1 {
        _pga_append_page(pga)
    }
    pages[page_id][idx] = elem
    length += 1
}

pga_pop :: proc(using pga: ^PageArray($T)) -> T {
    assert(length>0, "The PageArray is empty, you cannot pop element from it.")
    length -= 1
    return pages[length/page_size][length%page_size]
}

@private
_pga_append_page :: proc(using pga: ^PageArray($T)) {
    append(&pga.pages, make_slice([]T, page_size, page_allocator))
}

pga_len :: proc(using pga: ^PageArray($T)) {
    return length
}