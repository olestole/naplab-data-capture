#!/bin/bash

COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$COMMON/.." && pwd)"

run_in_screen() {
    screen -S "$1" -- \
        sh -ic "
            echo 'Running in SCREEN - Press Ctrl+A then Ctrl+D to detach'
            $2
            echo 'Still running in SCREEN - Press Ctrl+D to exit'
            exec bash
        "
}

get_commit_hash() {
    curl -s "https://api.github.com/repos/aasewold/transfuser/commits/$1" \
        | jq -r .sha \
        | head -c 8
}

get_commit_hash_interfuser() {
    curl -s "https://api.github.com/repos/aasewold/interfuser/commits/$1" \
        | jq -r .sha \
        | head -c 8
}

setup_transfuser() (
    set -euo pipefail

    mkdir -p results models

    if ../common/pretrained-models/check-prefuser.sh; then
        echo "Models already exist, skipping download"
    else
        echo "Downloading pre-trained model"
        ../common/pretrained-models/download-prefuser.sh
    fi
)

setup_interfuser() (
    set -euo pipefail

    mkdir -p results

    if ../common/pretrained-models/check-interfuser.sh; then
        echo "Models already exist, skipping download"
    else
        echo "Downloading models"
        ../common/pretrained-models/download-interfuser.sh
    fi
)

run_transfuser() (
    MODEL_PATH="$REPO/models/$MODEL_NAME"
    if [ ! -d "$MODEL_PATH" ]; then
        echo "Directory $MODEL_PATH does not exist"
        exit 1
    fi

    if [ -z "$RESUME" ]; then
        RUN_ID="$(date +%Y-%m-%dT%H-%M-%S)"
        echo "Starting new run with ID \"$RUN_ID\""
    else
        RUN_ID="$RESUME"
        echo "Resuming run with ID \"$RUN_ID\""
    fi

    sleep 1

    RESULT_PATH="results/${MODEL_NAME}/${RUN_ID}"
    echo Saving results to \"$RESULT_PATH\"

    if [ ! -z "$RESUME" ] && [ ! -d "$RESULT_PATH" ]; then
        echo "Directory $RESULT_PATH doesn't exists!"
        exit 1
    fi

    mkdir -p "$RESULT_PATH"

    TRANSFUSER_COMMIT="$(get_commit_hash "$TRANSFUSER_COMMIT")"
    MODEL_NAME_SUBST="$(echo "$MODEL_NAME" | tr , _)"
    CARLA_VERSION_SUBST="$(echo "$CARLA_VERSION" | tr . _)"
    RUN_ID_SUBST="$(echo "$RUN_ID" | tr '[:upper:]' '[:lower:]')"

    screen_name="ex-${MODEL_NAME}-${CARLA_VERSION}-${EVALUATION}-${RUN_ID}"
    compose_name="ex_${MODEL_NAME_SUBST}_${CARLA_VERSION_SUBST}-${EVALUATION}-${RUN_ID_SUBST}"

    echo "# Time: $(date '+%Y-%m-%d %H:%M:%S')" >> "$RESULT_PATH/desc.txt"
    echo "# Run ID: $RUN_ID" >> "$RESULT_PATH/desc.txt"
    echo "# CARLA version: $CARLA_VERSION" >> "$RESULT_PATH/desc.txt"
    echo "# Transfuser commit: $TRANSFUSER_COMMIT" >> "$RESULT_PATH/desc.txt"
    echo "# Model: $MODEL_NAME" >> "$RESULT_PATH/desc.txt"
    echo "# Evaluation: $EVALUATION" >> "$RESULT_PATH/desc.txt"
    echo >> "$RESULT_PATH/desc.txt"

    echo "# Please write a short description of the run:" >> "$RESULT_PATH/desc.txt"
    echo >> "$RESULT_PATH/desc.txt"
    echo >> "$RESULT_PATH/desc.txt"

    vim "$RESULT_PATH/desc.txt"

    sleep 1

    export CARLA_VERSION
    export TRANSFUSER_COMMIT
    export MODEL_PATH="$(realpath "$MODEL_PATH")"
    export RESULT_PATH="$(realpath "$RESULT_PATH")"

    run_in_screen "$screen_name" \
        "docker compose -p $compose_name -f $COMMON/transfuser.docker-compose.yml up --build"
)

run_interfuser() (
    MODEL_PATH="$REPO/models/$MODEL_NAME"
    if [ ! -d "$MODEL_PATH" ]; then
        echo "Directory $MODEL_PATH does not exist"
        exit 1
    fi

    if [ ! -f "$MODEL_PATH/interfuser.pth.tar" ]; then
        echo "File $MODEL_PATH/interfuser.pth.tar does not exist"
        echo "Download or make sure the model filename is correct"
        exit 1
    fi

    if [ -z "$RESUME" ]; then
        RUN_ID="$(date +%Y-%m-%dT%H-%M-%S)"
        echo "Starting new run with ID \"$RUN_ID\""
    else
        RUN_ID="$RESUME"
        echo "Resuming run with ID \"$RUN_ID\""
    fi

    sleep 1

    RESULT_PATH="results/${MODEL_NAME}/${RUN_ID}"
    echo Saving results to \"$RESULT_PATH\"

    if [ ! -z "$RESUME" ] && [ ! -d "$RESULT_PATH" ]; then
        echo "Directory $RESULT_PATH doesn't exists!"
        exit 1
    fi

    mkdir -p "$RESULT_PATH"

    INTERFUSER_COMMIT="$(get_commit_hash_interfuser "$INTERFUSER_COMMIT")"
    MODEL_NAME_SUBST="$(echo "$MODEL_NAME" | tr , _)"
    CARLA_VERSION_SUBST="$(echo "$CARLA_VERSION" | tr . _)"
    RUN_ID_SUBST="$(echo "$RUN_ID" | tr '[:upper:]' '[:lower:]')"

    screen_name="ex-${MODEL_NAME}-${CARLA_VERSION}-${EVALUATION}-${RUN_ID}"
    compose_name="ex_${MODEL_NAME_SUBST}_${CARLA_VERSION_SUBST}-${EVALUATION}-${RUN_ID_SUBST}"

    echo "# Time: $(date '+%Y-%m-%d %H:%M:%S')" >> "$RESULT_PATH/desc.txt"
    echo "# Run ID: $RUN_ID" >> "$RESULT_PATH/desc.txt"
    echo "# CARLA version: $CARLA_VERSION" >> "$RESULT_PATH/desc.txt"
    echo "# Interfuser commit: $INTERFUSER_COMMIT" >> "$RESULT_PATH/desc.txt"
    echo "# Model: $MODEL_NAME" >> "$RESULT_PATH/desc.txt"
    echo "# Evaluation: $EVALUATION" >> "$RESULT_PATH/desc.txt"
    echo >> "$RESULT_PATH/desc.txt"

    echo "# Please write a short description of the run:" >> "$RESULT_PATH/desc.txt"
    echo >> "$RESULT_PATH/desc.txt"
    echo >> "$RESULT_PATH/desc.txt"

    vim "$RESULT_PATH/desc.txt"

    sleep 1

    export CARLA_IMAGE
    export CARLA_VERSION
    export INTERFUSER_COMMIT
    export MODEL_PATH="$(realpath "$MODEL_PATH")"
    export RESULT_PATH="$(realpath "$RESULT_PATH")"

    run_in_screen "$screen_name" \
        "docker compose -p $compose_name -f $COMMON/interfuser.docker-compose.yml up --build"
)

select_evaluation() {
    PS3='Select evaluation: '
    options=("town05" "42routes" "longest6" "Quit")
    select eval in "${options[@]}"
    do
        case $eval in
            "town05")
                export ACTOR_AMOUNT=120
                break
                ;;
            "42routes")
                export ACTOR_AMOUNT=town
                break
                ;;
            "longest6")
                break
                ;;
            "Quit")
                exit 0
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done

    export EVALUATION=$eval
}
