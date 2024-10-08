#!/usr/bin/env bash

set -u

path_this="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)/$(basename -- "${BASH_SOURCE[0]}")"
dir_this="$(dirname -- "${path_this}")"
base_this="$(basename -- "${path_this}")"
[ -f "${path_this}" ] && [ -d "${dir_this}" ] && [ -f "${dir_this}/${base_this}" ] || ! echo >&2 "ERROR: ${base_this}: could not generate paths" || exit 1

__parse_args() {
    __is_bool() { [ "${1}" == 'true' ] || [ "${1}" == 'false' ] || ! echo >&2 "ERROR: ${base_this}: '${1}' is not 'true' or 'false'"; }
    __is_dir() { [ -d "${1}" ] || ! echo >&2 "ERROR: ${base_this}: dir '${1}' does not exist"; }
    __is_file() { [ -f "${1}" ] || ! echo >&2 "ERROR: ${base_this}: file '${1}' does not exist"; }
    while (("${#}")); do
        case "${1}" in
        #### pass --dry-run to underlying script
        # -d | --dry-run) dry_run='true' ;;
        #### check unstaged files even if they are uncached (not tracked by git)
        --c1 | --check-unstaged)
            __is_bool "${2}" || return "${?}"
            check_unstaged="${2}"
            shift
            ;;
        #### print files to be formatted
        --pf | --print-format-files)
            __is_bool "${2}" || return "${?}"
            print_format_files="${2}"
            shift
            ;;
        #### print files that will not be formatted
        --print-skipped)
            __is_bool "${2}" || return "${?}"
            print_skipped="${2}"
            shift
            ;;
        #### format script path
        # --ps | --path-script)
        #     __is_file "${2}" || return "${?}"
        #     path_script="${2}"
        #     shift
        #     ;;
        #### dir to locate files in
        --df | --dir-format)
            __is_dir "${2}" || return "${?}"
            dir_format="${2}"
            shift
            ;;
        #### handle unexpected cmd args
        *) echo >&2 "ERROR: ${base_this}: arg ${1} is unexpected" && return 1 ;;
        esac
        shift
    done
}

__is_true() {
    [ "${1}" == 'true' ] && return
    [ "${1}" == 'false' ] && return 1
    echo >&2 "FATAL: ${base_this}: '${1}' should be 'true' or 'false', aborting abruptly..."
    exit 1
}

file_format() {
    #### default vars
    ## paths
    local dir_format='.'
    ## switches
    local check_unstaged='false'
    # local dry_run='false'
    local print_format_files='true'
    local print_skipped='false'
    ####
    __parse_args "${@}" || return "${?}"
    ####
    #### files to accumulate
    local files_format=()
    local files_binary=()
    #### gather fi
    while IFS= read -r -d $'\0' file; do
        if ! git ls-files --error-unmatch "${file}" >/dev/null 2>&1; then
            __is_true "${check_unstaged}" || continue
            git check-ignore --quiet "${file}" && continue
        fi
        local text_attr=''
        text_attr="$(git -C "${dir_format}" check-attr -z text "${file}" | cut -d '' -f3- | tr -d '\000')" || return "${?}"
        [ "${text_attr}" == 'set' ] && files_format+=("${file}") || files_binary+=("${file}")
    done < <(find "${dir_format}" -type f -print0)
    if __is_true "${print_format_files}"; then
        echo >&2 "INFO: ${base_this}: listing files to be formatted:"
        for file in "${files_format[@]}"; do
            echo >&2 "      ${file}"
        done
        # if __is_true "${dry_run}";
        #     path_script --dry-run "${files_format[@]}"
        # else
        #     path_script "${files_format[@]}"
        # fi
    fi
    if __is_true "${print_skipped}"; then
        echo >&2 "INFO: ${base_this}: listing files that will not be formatted:"
        for file in "${files_binary[@]}"; do
            echo >&2 "      ${file}"
        done
    fi
}

file_format "${@}" || exit "${?}"
