package main

import "core:os"
import "core:strings"

scan_text :: proc(text: string, info : ^TaskInfo) {
    comment := false
    
    text_ite := text
    for line in strings.split_lines_iterator(&text_ite) {
        info.result += 1
        is_empty := true
        for b in line {
            if !strings.is_space(cast(rune)b) {
                is_empty = false
                break;
            }
        }
        if is_empty do info.blank += 1
        else do info.code += 1
    }
}