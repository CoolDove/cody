package main


scan_text :: proc(text: string, info : ^TaskInfo) {
    lines :i64= 0
    empty := true
    comment := false

    for b in text {
        if !empty && (b == ' ' || b == '\t' || b == '\r') {
            continue
        }
        
        if b == '\n' {
            info.result += 1
            if empty {
                info.blank += 1
            } else if comment {
                info.comment += 1
            } else {
                info.code += 1
            }
            empty = true
        } else {
            empty = false
        }
    }
}