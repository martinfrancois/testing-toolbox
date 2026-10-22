#!/usr/bin/env bash

# Remove only this demo's labelled resources, by ID so duplicate names are safe.
# Preflight uses its own scope to leave the presenter's running demo alone.
set -euo pipefail

if [[ $# -gt 1 ]]; then
    printf 'Usage: %s [scope]\n' "$0" >&2
    exit 2
fi
scope="${1:-presentation}"
label="testing-toolbox.pumba=$scope"

container_ids="$(docker ps --all --quiet --filter "label=$label")"
for id in $container_ids; do
    docker rm --force "$id"
done

network_ids="$(docker network ls --quiet --filter "label=$label")"
for id in $network_ids; do
    docker network rm "$id"
done
