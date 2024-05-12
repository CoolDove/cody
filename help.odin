package main


import "core:os"
import "core:io"
import "core:fmt"

help :: proc() {
    fmt.print("usage: cody [-q | --quiet] [-c | --color] [-p | --progress] [-ns | --no-sum] [-rs | --reverse-sort]\n")
    fmt.print("            [-ext .ext0 .ext1 .ext2 ... ]\n")
    fmt.print("            [-dir dir0 dir1 dir2 ... ]\n")
    fmt.print("            [-direxclude direxclude0 direxclude1 ... ]\n")
    fmt.print("            [-threads:{thread count}]\n")
    fmt.print("            [-sort:{default|total_line|code_line|blank_line|comment_line}]\n")
    fmt.print("            [-formats {format string}]\n")
    fmt.print("\nexamples:\n")
    fmt.print("cody -ext .cpp .h -dir ./src -q -p\n")
    fmt.print("cody -direxclude ./vendor doc ./build -ext .odin .glsl\n")
    fmt.print("cody -ns -format \"%(file)-%(file-short): %(total), %(code), %(blank), %(comment)\"\n")
    fmt.print("\ncommands:\n")
    fmt.print("cody rc \t# generate a .codyrc for the workspace (this function will be deprecated).\n")
    fmt.print("cody version \t# Show the version.\n")
    fmt.print("cody help \t# For help.\n")
}

help_rc :: proc() {
    rc_example :string: 
`directories: "C:/The/Directory", "./You/Want/To/Count"
ignore_directories: "./if_you/want_to", "ignore_some_dir"
extensions : ".code", ".ext",
quiet: false
color: false
progress: true
`
    if os.exists("./.codyrc") {
        os.write_entire_file("./.codyrc_example", transmute([]u8)rc_example)
        fmt.print(".codyrc example generated. You can rename it as '.codyrc' to make it work.\n")
    } else {
        os.write_entire_file("./.codyrc", transmute([]u8)rc_example)
        fmt.print(".codyrc example generated.\n")
    }
}

help_version :: proc() {
    fmt.printf("Cody version: 114514.0.9")
}
