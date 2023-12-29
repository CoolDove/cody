package main

import "core:os"
import "core:strings"
import "core:fmt"

ArgsReaderConfig :: struct {
    rule : ArgsReaderRule,
    action : ArgsReaderAction,
}

ArgsReaderRule :: union {
    ArgsRuleIs,
    ArgsRuleFollowBy,
    ArgsRulePrefix,
}

ArgsReaderAction :: union {
    ArgsReaderActionHandler,
}
ArgsReaderActionHandlerFunc :: #type proc(arg:string, user_data: rawptr)
ArgsReaderActionHandler :: struct {
    func : ArgsReaderActionHandlerFunc,
    data : rawptr,
}

ArgsRuleIs :: struct {
    text: string,
}
ArgsRuleFollowBy :: distinct ArgsRuleIs
ArgsRulePrefix :: distinct ArgsRuleIs

args_read :: proc(configs : ..ArgsReaderConfig) {
    count := cast(i32)len(os.args)
    idx :i32= 1
    ite_args: for idx < count {
        arg := os.args[idx]        
        for &config in configs {
            if _apply(&config, &idx) do continue ite_args
        }
        return
    }
}

argr_is :: proc(text: string) -> ArgsRuleIs {
    return {text}
}
argr_follow_by :: proc(text: string) -> ArgsRuleFollowBy {
    return {text}
}
argr_prefix :: proc(text: string) -> ArgsRulePrefix {
    return {text}
}

arga_action :: proc(func: ArgsReaderActionHandlerFunc, data: rawptr=nil) -> ArgsReaderAction {
    return ArgsReaderActionHandler{func,data}
}

@(private="file")
_apply :: proc(using config: ^ArgsReaderConfig, arg_idx: ^i32) -> bool {
    arg := os.args[arg_idx^]
    switch r in rule {
    case ArgsRuleIs:
        if r.text == arg {
            arg_idx^ += 1
            _action(config, arg)
            return true
        }
    case ArgsRuleFollowBy:
        if r.text == arg {
            arg_idx^ += 1
            if arg_idx^ >= auto_cast len(os.args) { return false }
            _action(config, os.args[arg_idx^])
            arg_idx^ += 1
            return true
        }
    case ArgsRulePrefix:
        if strings.has_prefix(arg, r.text) {
            arg_idx^ += 1
            _action(config, arg[len(r.text):])
            return true
        }
    }
    return false
}

@(private="file")
_action :: proc(using config: ^ArgsReaderConfig, arg: string) -> bool {
    if action == nil do return false
    switch a in action {
    case ArgsReaderActionHandler:
        a.func(arg, a.data)
    }
    return false
}