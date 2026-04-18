default:
    @just --list

build *args:
    zig build {{args}}

run *args:
    zig build
    sudo ./zig-out/bin/lumem {{args}}

test:
    zig build test

check: test

fmt:
    zig fmt build.zig src/*.zig

clean:
    rm -rf .zig-cache zig-out

rebuild: clean build