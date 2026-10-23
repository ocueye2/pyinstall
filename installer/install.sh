#!/bin/sh
# Install the command described by install.conf (or a supplied .conf file).
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
config_file=${1:-"$script_dir/install.conf"}

if [ ! -f "$config_file" ]; then
    echo "Configuration file not found: $config_file" >&2
    exit 1
fi
config_dir=$(CDPATH= cd -- "$(dirname -- "$config_file")" && pwd)

name=
entrypoint=
requirements=
install_dir=
venv_dir=

# The configuration format is deliberately small: key=value, with # comments.
while IFS='=' read -r key value || [ -n "$key" ]; do
    case "$key" in
        '' | \#*) continue ;;
        name) name=$value ;;
        entrypoint) entrypoint=$value ;;
        requirements) requirements=$value ;;
        install_dir) install_dir=$value ;;
        venv_dir) venv_dir=$value ;;
        *) echo "Unknown setting in $config_file: $key" >&2; exit 1 ;;
    esac
done < "$config_file"

if [ -z "$name" ] || [ -z "$entrypoint" ]; then
    echo "Configuration must set both name and entrypoint." >&2
    exit 1
fi

case "$name" in
    */* | . | ..) echo "name must be a command name, not a path: $name" >&2; exit 1 ;;
esac

case "$entrypoint" in
    /*) source_file=$entrypoint ;;
    *) source_file="$config_dir/$entrypoint" ;;
esac

if [ ! -f "$source_file" ]; then
    echo "Entrypoint not found: $source_file" >&2
    exit 1
fi

if [ -z "$install_dir" ]; then
    install_dir=${XDG_BIN_HOME:-"$HOME/.local/bin"}
fi
if [ -z "$venv_dir" ]; then
    venv_dir="$install_dir/.${name}-venv"
fi

if [ -n "$requirements" ]; then
    case "$requirements" in
        /*) requirements_file=$requirements ;;
        *) requirements_file="$config_dir/$requirements" ;;
    esac
    if [ ! -f "$requirements_file" ]; then
        echo "Requirements file not found: $requirements_file" >&2
        exit 1
    fi
fi

mkdir -p "$install_dir"
python3 -m venv "$venv_dir"
if [ -n "$requirements" ]; then
    "$venv_dir/bin/python" -m pip install -r "$requirements_file"
fi

app_file="$venv_dir/$name.py"
cp "$source_file" "$app_file"
printf '%s\n' "$name" > "$venv_dir/.mediaterm-installer"
printf '%s\n' '#!/bin/sh' "exec \"$venv_dir/bin/python\" \"$app_file\" \"\$@\"" > "$install_dir/$name"
chmod 755 "$install_dir/$name"

echo "Installed $name to $install_dir/$name (venv: $venv_dir)"
case ":$PATH:" in
    *":$install_dir:"*) ;;
    *) echo "Add $install_dir to PATH, then run: $name" ;;
esac
