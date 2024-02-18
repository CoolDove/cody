package main

import "core:os"
import "core:c/libc"
import "core:intrinsics"
import "core:io"
import "core:fmt"
import "core:mem"
import "core:log"
import "core:thread"
import "core:strings"
import "core:math"
import "core:unicode/utf8"
import "core:path/filepath"
import "core:time"

import clc "./collection"
import ansi "./ansi_code"

TaskInfo :: struct {
    ctx : ^CodyContext,
    idx : i64,

    result : i64,
    comment : i64,
    code : i64,
    blank : i64,
}

print_arg :: proc(arg: string, data: rawptr) -> bool {
    fmt.printf("arg: {}\n", arg)
    return true
}

main :: proc() {
    context.logger = log.create_console_logger(); defer log.destroy_console_logger(context.logger)

    codyrc_init(); defer codyrc_release()

    {// read arguments
        action_add_extension :: proc(arg: string, data: rawptr) -> bool {
            codyrc_add_extension(arg)
            return true
        }
        action_add_directory :: proc(arg: string, data: rawptr) -> bool {
            codyrc_add_directory(arg)
            return true
        }
        action_add_directory_excluded :: proc(arg: string, data: rawptr) -> bool {
            codyrc_add_directory_excluded(arg)
            return true
        }
        action_invalid_arg :: proc(arg: string, data: rawptr) -> bool {
            fmt.printf("Invalid arg: -{}.\n", arg)
            return false
        }
        action_help :: proc(arg: string, data: rawptr) -> bool {
            help()
            return false
        }
        action_version :: proc(arg: string, data: rawptr) -> bool {
            help_version()
            return false
        }
        action_rc :: proc(arg: string, data: rawptr) -> bool {
            help_rc()
            return false
        }
        args_ok := args_read(
            {argr_is("help"), arga_action(action_help)},
            {argr_is("-h"), arga_action(action_help)},
            {argr_is("--help"), arga_action(action_help)},
            {argr_is("version"), arga_action(action_version)},
            {argr_is("-v"), arga_action(action_version)},
            {argr_is("--version"), arga_action(action_version)},
            {argr_is("rc"), arga_action(action_rc)},

            {argr_is("--quiet"), arga_set(&config.quiet)},
            {argr_is("-q"), arga_set(&config.quiet)},
            {argr_is("--color"), arga_set(&config.color)},
            {argr_is("-c"), arga_set(&config.color)},
            {argr_is("--progress"), arga_set(&config.progress)},
            {argr_is("-p"), arga_set(&config.progress)},

            {argr_is("--no-sum"), arga_set(&config.no_sum)},
            {argr_is("-ns"), arga_set(&config.no_sum)},

            {argr_follow_by("-format"), arga_set(&config.format)},
            
            {argr_follow_by("-ext", ARGR_FOLLOW_FALLBACK), arga_action(action_add_extension)},
            {argr_follow_by("-dir", ARGR_FOLLOW_FALLBACK), arga_action(action_add_directory)},
            {argr_follow_by("-direxclude", ARGR_FOLLOW_FALLBACK), arga_action(action_add_directory_excluded)},


            {argr_prefix("-threads:"), arga_set(&config.thread_count)},
            {argr_prefix("-task-page-size:"), arga_set(&config.task_page_size)},
            {argr_prefix("-comment-style:"), arga_action(action_invalid_arg)},

            {argr_prefix("-"), arga_action(action_invalid_arg)},
        )
        if !args_ok do return

    }

    if len(os.args) == 2 && (os.args[1] == "help" || os.args[1] == "--h") {
        help()
        return
    }


    cody:= cody_create(math.clamp(config.task_page_size, 1, 1024)); defer cody_destroy(&cody)

    dir :string= os.get_current_directory()
    // os.set_current_directory(dir)

    codyrc_load(dir)

	codyrc_bake_ignored_dirs()

    cody_begin(&cody, math.clamp(config.thread_count, 1, 64))
        if len(config.directories) == 0 {
            ite(dir, &cody)
        } else {
            for d in config.directories {
                ite(clc.pstr_to_string(d), &cody)
            }
        }
    cody_end(&cody)

    files_count := clc.pga_len(&cody.tasks)
    total_lines, total_lines_code, total_lines_blank, total_lines_comment := 0,0,0,0
	sb : strings.Builder ; strings.builder_init(&sb) ; defer strings.builder_destroy(&sb)
    for h, idx in cody.handles {
        task := clc.pga_get_ptr(&cody.tasks, idx)
        total_lines += auto_cast task.result
        total_lines_code += auto_cast task.code
        total_lines_blank += auto_cast task.blank
        total_lines_comment += auto_cast task.comment

        if !config.quiet {
			strings.builder_reset(&sb)
            fi, err_fi := os.fstat(h)

			format_string := "%(file-short):\t%(total) total, %(code) codes." if config.format == "" else config.format;
			output_string := output_formatted(format_string, h, task, &sb)
			fmt.println(output_string)
        }
        os.close(h)
    }
    if !config.quiet do fmt.print("\n")

	if !config.no_sum {
		fmt.printf("Files count: {}\n", files_count)
		fmt.printf("Total time: {} s\n", time.duration_seconds(time.stopwatch_duration(cody.stopwatch)))
		if config.color {
			fmt.printf("Total: {}, code lines: \033[4m{}\033[0m, blank lines: \033[4m{}\033[0m, comment lines: \033[4m{}\033[0m.", 
				total_lines, total_lines_code, total_lines_blank, total_lines_comment)
		} else {
			fmt.printf("Total: {}, code lines: {}, blank lines: {}, comment lines: {}.", 
				total_lines, total_lines_code, total_lines_blank, total_lines_comment)
		}
	}

}

ite :: proc(path: string, ctx: ^CodyContext) {
    if os.is_dir(path) {
        if is_dir_ignored(path) do return 
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

update :: proc(using cody: ^CodyContext) {
    ms := time.duration_seconds(time.stopwatch_duration(cody.stopwatch))
    if ms - cody.last_frame_time > 0.05 {
        using clc
        finished := 0
        idx : int
        for task in pga_ite(&cody.tasks, &idx) {
            if task.result != -1 do finished += 1
        }
        last_frame_time = ms
        if config.progress {
            ansi.show_cursor(false)
            ansi.store_cursor()
            ansi.erase(.FromCursorToEnd)
            fmt.printf("Progress: {}/{}", finished, pga_len(&cody.tasks))
            ansi.restore_cursor()
            ansi.show_cursor(true)
        }
    }
}

append_task :: proc(cody: ^CodyContext, handle: os.Handle) {
    idx := len(cody.handles)
    append(&cody.handles, handle)
    task := clc.pga_append(&cody.tasks, TaskInfo {
        ctx = cody,
        idx = auto_cast idx,
        result = -1,
    })
    thread.pool_add_task(&cody.thread_pool, context.allocator, task_count_file, task)
}

is_ext_match :: proc(extension : string) -> bool {
    for ext_pstr in config.extensions {
        if extension == clc.pstr_to_string(ext_pstr) do return true
    }
    return false
}

is_dir_ignored :: proc(path: string) -> bool {
    if len(path) > 4 && path[len(path)-4:] == ".git" do return true
    if len(config.ignored_directories_fullpath) > 0 {
        if di, err := os.stat(path); err == os.ERROR_NONE {
            for ignore_dir in config.ignored_directories_fullpath {
                if ignore_dir == di.fullpath do return true
            }
        }
    }
    return false
}

task_count_file :: proc(task: thread.Task) {
    context.allocator = task.allocator
    info := cast(^TaskInfo)task.data
    using info
    h := ctx.handles[idx]

    buffer_idx :int
    buffer :^[]u8

    for &used, idx in ctx.file_buffers_using {
        if !used {
            used = true
            buffer = &ctx.file_buffers[idx]
            buffer_idx = idx
            break
        }
    }
    assert(buffer != nil, "File buffers ran out. This shouldn't happen.")
    defer ctx.file_buffers_using[buffer_idx] = false

    lines :i64= 0

    if file_size, err := os.file_size(h); err == os.ERROR_NONE && file_size > 0 {

        if auto_cast file_size > len(buffer) {
            delete(buffer^)
            buffer^ = make([]u8, file_size)
        }

        read_bytes_count, read_err := os.read_full(h, buffer[:file_size])
        
        if read_err == os.ERROR_NONE {
            info.result = 0
            scan_text(transmute(string)buffer[:file_size], info)
        } else {
            log.errorf("Read file error: {}", read_err)
        }
    }
}
