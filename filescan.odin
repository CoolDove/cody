package main

import "core:os"
import "core:strings"

// TODO: Support /**/ block comment.
// TODO: Support other block style.

scan_text :: proc(text: string, info : ^TaskInfo) {
    text_ite := text
    for line in strings.split_lines_iterator(&text_ite) {
        info.result += 1
        is_empty := true
        is_comment := false
        comment_state := 0
        for b in line {
            if is_empty && !strings.is_space(cast(rune)b) {
                is_empty = false
            }
            if comment_state == 0 {
                if b == '/' do comment_state = 1
            } else if comment_state == 1 {
                if b == '/' {
                    comment_state = 2
                    is_comment = true
                    break;
                } else {
                    comment_state = 0
                }
            }
        }
        if is_empty do info.blank += 1
        else if is_comment do info.comment += 1
        else do info.code += 1
    }
}