#!/bin/sh
# Remove the command described by install.conf (or a supplied .conf file).
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
config_file=${1:-"$script_dir/install.conf"}

if [ ! -f "$config_file" ]; then
    echo "Configuration file not found: $config_file" >&2
    exit 1
fi

name=
install_dir=
venv_dir=

while IFS='=' read -r key value || [ -n "$key" ]; do
    case "$key" in
        '' | \#*) continue ;;
        name) name=$value ;;
        entrypoint) ;;
        requirements) ;;
        version | description | entry_function) ;;
        install_dir) install_dir=$value ;;
        venv_dir) venv_dir=$value ;;
        *) echo "Unknown setting in $config_file: $key" >&2; exit 1 ;;
    esac
done < "$config_file"

if [ -z "$name" ]; then
    echo "Configuration must set name." >&2
    exit 1
fi

case "$name" in
    */* | . | ..) echo "name must be a command name, not a path: $name" >&2; exit 1 ;;
esac

if [ -z "$install_dir" ]; then
    install_dir=${XDG_BIN_HOME:-"$HOME/.local/bin"}
fi
if [ -z "$venv_dir" ]; then
    venv_dir="$install_dir/.${name}-venv"
fi

target="$install_dir/$name"
if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    echo "Not installed: $target" >&2
    exit 1
fi

rm "$target"
if [ ! -f "$venv_dir/.mediaterm-installer" ] || [ "$(cat "$venv_dir/.mediaterm-installer")" != "$name" ]; then
    echo "Removed $target, but did not remove unrecognized venv: $venv_dir" >&2
    exit 1
fi

rm -rf "$venv_dir"
echo "Removed $target and $venv_dir"
