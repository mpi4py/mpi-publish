#!/bin/bash
set -euo pipefail

usage() { echo "usage: $0 -w {dest_dir} {wheel}" && exit 1; }

test "${1:-}" = "-w" || usage
test "${2:-}" != ""  || usage
test "${3:-}" != ""  || usage
test "${4:-}" == ""  || usage

dest_dir=$2
wheel=$3

arch=$(uname -m)

case "$(uname)" in
    Linux)
        auditwheel repair \
            --only-plat \
            --exclude "libefa.so.*" \
            --exclude "libpsm2.so.*" \
            --exclude "libmlx5.so.*" \
            --exclude "librdmacm.so.*" \
            --exclude "libibverbs.so.*" \
            -w "${dest_dir}" "${wheel}"
        ;;
    Darwin)
        delocate-wheel -v \
            --require-archs "${arch}" \
            --ignore-missing-dependencies \
            -w "${dest_dir}" "${wheel}"
        ;;
esac
