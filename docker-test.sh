#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="ncku-compiler-hw1:ubuntu22"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

docker build -t "$IMAGE_NAME" "$PROJECT_ROOT"

if [ -t 0 ]; then
    DOCKER_TTY=(-it)
else
    DOCKER_TTY=(-i)
fi

docker run --rm "${DOCKER_TTY[@]}" \
    --mount "type=bind,src=$PROJECT_ROOT,dst=/src,readonly" \
    "$IMAGE_NAME" \
    bash -lc '
        set -euo pipefail
        tar -C /src \
            --exclude=./build \
            --exclude=./cmake-build-debug \
            --exclude=./.git \
            -cf - . | tar -C /work -xf -
        chmod +x /work/test.sh
        cd /work
        ./test.sh "$@"
    ' -- "$@"
