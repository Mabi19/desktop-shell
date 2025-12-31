#!/bin/bash

function join_by {
    local d=${1-} f=${2-}
    if shift 2; then
        printf %s "$f" "${@/#/$d}"
    fi
}

function unquote {
    # best way to unquote a string, apparently
    python -c 'import sys; print(eval(sys.argv[1]))' "$1"
}

function dispatch {
    args="[\"$(join_by '", "' "$@")\"]"
    result=$(gdbus call -e -d land.mabi.shell -o /land/mabi/shell -m land.mabi.shell.ipc.Dispatch "$args")
    result=${result:1:-2}
    result=$(unquote "$result")
    echo "$result"
}

function print_help {
    echo "usage: mabictl <command> [args...]"
    echo ""
    echo "commands:"
    echo "    dispatch - send an IPC call to mabi-shell"
    echo "    help     - show this information"
    echo "note: unknown commands are interpreted as dispatch calls"
}

case $1 in
    "")
        print_help
        ;;
    "help")
        print_help
        ;;
    "dispatch")
        shift 1;
        dispatch "$@"
        ;;
    *)
        dispatch "$@"
        ;;
esac
