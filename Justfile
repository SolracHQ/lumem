default:
    @just --list

build *args:
    zig build {{args}}

run *args:
    zig build
    sudo ./zig-out/bin/lumem {{args}}

target:
    zig build target

docs:
    mkdir -p stubs && zig build docs > stubs/lumem.d.lua

dylib:
    zig build dylib && cp zig-out/lib/liblumem.so lumem.so

test:
    zig build test

check: test

fmt:
    zig fmt build.zig src/*.zig

clean:
    rm -rf .zig-cache zig-out

rebuild: clean build