#!/bin/bash

function join_by {
    local d=${1-} f=${2-}
    if shift 2; then
        printf %s "$f" "${@/#/$d}"
    fi
}

function unquote {
    # best way to unquote a string
    python -c 'import sys; print(eval(sys.argv[1]))' "$1"
}

function dispatch {
    args="[\"$(join_by '", "' "$@")\"]"
    result=$(gdbus call -e -d land.mabi.shell -o /land/mabi/shell -m land.mabi.shell.ipc.Dispatch "$args")
    result=${result:1:-2}
    result=$(unquote "$result")
    echo "$result"
}

case $1 in
    "help")
        # TODO
        echo "This is the help text"
        ;;
    "dispatch")
        shift 1;
        dispatch "$@"
        ;;
    *)
        dispatch "$@"
        ;;
esac
