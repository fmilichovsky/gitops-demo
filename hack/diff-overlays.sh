#!/usr/bin/env bash

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <group> <first-overlay-name> <second-overlay-name>"
    exit 1
fi

group="$1"
first_overlay="$2"
second_overlay="$3"

path_first_overlay="${group}/overlays/${first_overlay}"
path_second_overlay="${group}/overlays/${second_overlay}"

temp_file_first=$(mktemp)
temp_file_second=$(mktemp)

kustomize build "$path_first_overlay" > "$temp_file_first"
kustomize build "$path_second_overlay" > "$temp_file_second"

diff -u "$temp_file_first" "$temp_file_second"

rm -f "$temp_file_first" "$temp_file_second"
