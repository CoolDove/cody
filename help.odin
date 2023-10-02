package main


import "core:os"
import "core:io"
import "core:fmt"

help :: proc() {

    rc_example :string: 
`directories: "C:/The/Directory", "./You/Want/To/Count"
ignore_directories: "./if_you/want_to", "ignore_some_dir"
extensions : ".code", ".ext",
quiet: false
`
    if os.exists("./.codyrc") {
        os.write_entire_file("./.codyrc_example", transmute([]u8)rc_example)
    } else {
        os.write_entire_file("./.codyrc", transmute([]u8)rc_example)
    }
    fmt.print(".codyrc example generated.\n")
}