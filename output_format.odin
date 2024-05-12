package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:path/filepath"

/*
Available variables:

%(file)
%(file-short)
%(total)
%(code)
%(blank)
%(comment)
*/

output_formatted :: proc(format_string : string, h: os.Handle, result: ^OutputResult, sb: ^strings.Builder) -> string {
	using strings

    fi, err_fi := os.fstat(h)
    fullpath := strings.trim_prefix(fi.fullpath, "\\\\?\\")
	shortpath := filepath.base(fullpath)

	var := false
	begin, idx := 0,0
	for idx < len(format_string) {
		if format_string[idx] == '%' {
			if end_idx := index_byte(format_string[idx:], ')'); end_idx != -1 {
				var_name := format_string[idx:idx+end_idx+1]
				if var_name == "%(file)" {
					if config.color do write_string(sb, "\033[43m")
					write_string(sb, fullpath)
					if config.color do write_string(sb, "\033[49m")
					idx += end_idx+1
				} else if var_name == "%(file-short)" {
					if config.color do write_string(sb, "\033[43m")
					write_string(sb, shortpath)
					if config.color do write_string(sb, "\033[49m")
					idx += end_idx+1
				} else if var_name == "%(total)" {
					write_i64(sb, cast(i64)result.total)
					idx += end_idx+1
				} else if var_name == "%(code)" {
					write_i64(sb, cast(i64)result.code)
					idx += end_idx+1
				} else if var_name == "%(blank)" {
					write_i64(sb, cast(i64)result.blank)
					idx += end_idx+1
				} else if var_name == "%(comment)" {
					write_i64(sb, cast(i64)result.comment)
					idx += end_idx+1
				} else {
					write_byte(sb, format_string[idx])
					idx += 1
				}
			} else {
				write_byte(sb, format_string[idx])
				idx += 1
			}
		} else {
			write_byte(sb, format_string[idx])
			idx += 1
		}
	}
	return to_string(sb^)
}
