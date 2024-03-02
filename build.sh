#!/bin/bash

set -e

# kill child processes on exit
trap 'kill 0' SIGINT SIGTERM

# the absolute path to the directory holding this file
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

STATIC="${SCRIPT_DIR}/static"
BUILD="${SCRIPT_DIR}/_build"
REPO="${SCRIPT_DIR}/_rocket"
OUTPUT="${SCRIPT_DIR}/_output"

GIT_URL=https://github.com/rwf2/Rocket.git
EXCLUDE=("HEAD" "v0.1" "v0.2" "v0.3" "v0.5-rc")
MUST_PASS=("master" "v0.5")
CMD="./scripts/mk-docs.sh"

function build() {
    local worktree=$1
    local branch=$(basename "${worktree}")
    pushd "${worktree}" > /dev/null 2>&1
        git fetch -q

        # if there are no changes and we've already built, do nothing
        if [ $(git rev-parse HEAD) == $(git rev-parse @{u}) ]; then
            if [ -f "${worktree}/_success" ] && [ -d "${worktree}/target/doc" ]; then
                echo "✓ ${branch} build is up to date"
                return 0
            fi
        fi

        echo "> updating ${branch}"
        git reset --hard origin/${branch}
        git update-ref -d refs/remotes/origin/${branch}
        git pull --ff-only

        rm -f "${worktree}/_success"
        eval "${CMD}" > "${worktree}/stdout.log" 2> "${worktree}/stderr.log"
        touch "${worktree}/_success"
    popd > /dev/null 2>&1
}

if [[ "$1" == c* ]] || [[ "$1" == --c* ]]; then
    echo "> removing artifacts"
    rm -rf _*
    echo "✓ done"
    exit 0
fi

if ! [ -d ${REPO} ]; then
    echo "> cloning ${GIT_URL}"
    echo "↦ ${REPO}"
    git clone -q "${GIT_URL}" "${REPO}"
fi

pushd "${REPO}" > /dev/null 2>&1
    echo "> detaching"
    git checkout --detach
    git fetch

    tasks=()
    for branch in $(git for-each-ref refs/remotes/origin --format="%(refname:lstrip=3)"); do
        if [[ " ${EXCLUDE[*]} " =~ " ${branch} " ]]; then
            continue
        fi

        worktree="${BUILD}/${branch}"
        if ! [ -d "${worktree}" ]; then
            git worktree add "${worktree}" "${branch}"
        fi

        echo "> building ${branch}"
        (build "${worktree}") &
        tasks+=("$! ${branch}")
    done

    start=$SECONDS
    last=$start
    while [ -n "$(jobs -rp)" ]; do
        current=$SECONDS
        if (( current - last >= 10 )); then
            echo "[$(($current - $start))s] working..."
            last=$current
        fi

        sleep 0.5
    done

    rm -rf "${OUTPUT}"
    mkdir "${OUTPUT}"
    for task in "${tasks[@]}"; do
        IFS=' ' read -r pid branch <<< "${task}"
        worktree="${BUILD}/${branch}"
        status=0; wait ${pid} || status=$?
        if [ $status -eq 0 ]; then
            echo "✓ ${branch} (${pid}) build complete"
            cp -R "${worktree}/target/doc" "${OUTPUT}/${branch}"
        else
            echo ""
            echo "x ${branch} failed (pid=$pid, exit=$status)"
            echo "======================== STDOUT ============================"
            cat "${worktree}/stdout.log" 2>/dev/null || true
            echo "======================== STDERR ============================"
            cat "${worktree}/stderr.log" 2>/dev/null || true
            echo "============================================================"

            if [[ " ${MUST_PASS[*]} " =~ " ${branch} " ]]; then
                echo "FAILURE: ${branch} is in must pass list [${MUST_PASS[@]}]"
                echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                exit 1
            fi
        fi
    done
popd > /dev/null 2>&1

echo "> copying static assets to output"
cp -r "${STATIC}/"* "${OUTPUT}"

echo "✓ success"
