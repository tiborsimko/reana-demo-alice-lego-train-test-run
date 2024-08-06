#!/usr/bin/env bash
#
# This file is part of REANA.
# Copyright (C) 2024 CERN.
#
# REANA is free software; you can redistribute it and/or modify it
# under the terms of the MIT License; see LICENSE file for more details.

set -o errexit
set -o nounset

check_commitlint () {
    from=${2:-master}
    to=${3:-HEAD}
    pr=${4:-[0-9]+}
    npx commitlint --from="$from" --to="$to"
    found=0
    while IFS= read -r line; do
        commit_hash=$(echo "$line" | cut -d ' ' -f 1)
        commit_title=$(echo "$line" | cut -d ' ' -f 2-)
        commit_number_of_parents=$(git rev-list --parents "$commit_hash" -n1 | awk '{print NF-1}')
        # (i) skip checking release commits generated by Release Please
        if [ "$commit_number_of_parents" -le 1 ] && echo "$commit_title" | grep -qP "^chore\(.*\): release"; then
            continue
        fi
        # (ii) check presence of PR number
        if ! echo "$commit_title" | grep -qP "\(\#$pr\)$"; then
            echo "✖   Headline does not end by '(#$pr)' PR number: $commit_title"
            found=1
        fi
        # (iii) check absence of merge commits in feature branches
        if [ "$commit_number_of_parents" -gt 1 ]; then
            if echo "$commit_title" | grep -qP "^chore\(.*\): merge "; then
                break  # skip checking maint-to-master merge commits
            else
                echo "✖   Merge commits are not allowed in feature branches: $commit_title"
                found=1
            fi
        fi
    done < <(git log "$from..$to" --format="%H %s")
    if [ $found -gt 0 ]; then
        exit 1
    fi
}

check_shellcheck () {
    find . -name "*.sh" -exec shellcheck {} \+
}

check_all () {
    check_commitlint
    check_shellcheck
}

if [ $# -eq 0 ]; then
    check_all
    exit 0
fi

arg="$1"
case $arg in
    --check-commitlint) check_commitlint "$@";;
    --check-shellcheck) check_shellcheck;;
    *) echo "[ERROR] Invalid argument '$arg'. Exiting." && exit 1;;
esac
