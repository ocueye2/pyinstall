#!/bin/sh
# Generate pyproject.toml from install.conf, then build an installable wheel.
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
dist_dir="$project_dir/dist"
config_file=${1:-"$script_dir/install.conf"}

if [ ! -f "$config_file" ]; then
    echo "Configuration file not found: $config_file" >&2
    exit 1
fi
config_dir=$(CDPATH= cd -- "$(dirname -- "$config_file")" && pwd)

name=
entrypoint=
requirements=
version=0.1.0
description=
entry_function=main

while IFS='=' read -r key value || [ -n "$key" ]; do
    case "$key" in
        '' | \#*) continue ;;
        name) name=$value ;;
        entrypoint) entrypoint=$value ;;
        requirements) requirements=$value ;;
        version) version=$value ;;
        description) description=$value ;;
        entry_function) entry_function=$value ;;
        install_dir | venv_dir) ;;
        *) echo "Unknown setting in $config_file: $key" >&2; exit 1 ;;
    esac
done < "$config_file"

if [ -z "$name" ] || [ -z "$entrypoint" ]; then
    echo "Configuration must set both name and entrypoint." >&2
    exit 1
fi

case "$entrypoint" in
    /*) source_file=$entrypoint ;;
    *) source_file="$config_dir/$entrypoint" ;;
esac
if [ ! -f "$source_file" ] || [ "${source_file##*.}" != "py" ]; then
    echo "entrypoint must name an existing Python file: $source_file" >&2
    exit 1
fi

source_dir=$(CDPATH= cd -- "$(dirname -- "$source_file")" && pwd)
case "$source_dir" in
    "$project_dir") source_dir_rel=. ;;
    "$project_dir"/*) source_dir_rel=${source_dir#"$project_dir"/} ;;
    *) echo "entrypoint must be inside the project: $source_file" >&2; exit 1 ;;
esac

module_name=${source_file##*/}
module_name=${module_name%.py}
case "$module_name" in
    '' | [0-9]* | *[!A-Za-z0-9_]*)
        echo "entrypoint filename must be a valid Python module name: $module_name" >&2
        exit 1
        ;;
esac

if [ -n "$requirements" ]; then
    case "$requirements" in
        /*) requirements_file=$requirements ;;
        *) requirements_file="$config_dir/$requirements" ;;
    esac
    if [ ! -f "$requirements_file" ]; then
        echo "Requirements file not found: $requirements_file" >&2
        exit 1
    fi
    requirements_dir=$(CDPATH= cd -- "$(dirname -- "$requirements_file")" && pwd)
    requirements_file="$requirements_dir/$(basename -- "$requirements_file")"
    case "$requirements_file" in
        "$project_dir"/*) requirements_rel=${requirements_file#"$project_dir"/} ;;
        *) echo "requirements must be inside the project: $requirements_file" >&2; exit 1 ;;
    esac
fi

case "$name$version$description$entry_function" in
    *'"'* | *'\\'*) echo "Package metadata cannot contain quotes or backslashes." >&2; exit 1 ;;
esac

{
    printf '%s\n' '[build-system]' 'requires = ["setuptools>=61"]' 'build-backend = "setuptools.build_meta"' ''
    printf '%s\n' '[project]' "name = \"$name\"" "version = \"$version\"" "description = \"$description\"" 'requires-python = ">=3.10"'
    if [ -n "$requirements" ]; then
        printf '%s\n' 'dynamic = ["dependencies"]'
    fi
    printf '%s\n' '' '[project.scripts]' "\"$name\" = \"$module_name:$entry_function\"" '' '[tool.setuptools]' "package-dir = {\"\" = \"$source_dir_rel\"}" "py-modules = [\"$module_name\"]"
    if [ -n "$requirements" ]; then
        printf '%s\n' '' '[tool.setuptools.dynamic]' "dependencies = {file = [\"$requirements_rel\"]}"
    fi
} > "$project_dir/pyproject.toml"

mkdir -p "$dist_dir"
python3 -m pip wheel --no-deps --no-build-isolation --wheel-dir "$dist_dir" "$project_dir"

echo "Generated $project_dir/pyproject.toml from $config_file"
echo "Package created in $dist_dir"
echo "Install it with: python3 -m pip install $dist_dir/$name-*.whl"
