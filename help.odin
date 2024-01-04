package main


import "core:os"
import "core:io"
import "core:fmt"

help :: proc() {
    fmt.print("usage: cody [-q | --quiet] [-c | --color] [-p | --progress]\n")
    fmt.print("            [-ext .ext0 .ext1 .ext2 ... ]\n")
    fmt.print("            [-dir dir0 dir1 dir2 ... ]\n")
    fmt.print("            [-direxclude direxclude0 direxclude1 ... ]\n")
    fmt.print("            [-threads:{thread count}]\n")
    fmt.print("\nexamples:\n")
    fmt.print("cody -ext .cpp .h -dir ./src -q -p\n")
    fmt.print("cody -direxclude ./vendor doc ./build -ext .odin .glsl\n")
    fmt.print("\ncommands:\n")
    fmt.print("cody rc \t# generate a .codyrc for the workspace.\n")
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
    fmt.printf("114514")
}