#!/bin/bash

#######################################
# Configuration
#######################################
source ./password.sh
source ./setting.sh

#######################################
# Runtime global variables
#######################################
declare -a connect_info=()
container_index=0
ccs_id=""
container_name=""
common_commands_combined=""
common_commands_combined_str=""
commands_combined_within_element=""
commands_combined_within_element_str=""

#######################################
# Utility functions
#######################################
make_ccs() {
    local log_file="$1"

    if [[ -z "${container_name}" ]]; then
        "${TWCC_CLI_CMD}" mk ccs \
            -itype "${IMAGE_TYPE}" \
            -img "${IMAGE_NAME}" \
            -gpu "${GPU}" \
            -wait -json > "${log_file}"
    else
        "${TWCC_CLI_CMD}" mk ccs \
            -n "${container_name}" \
            -itype "${IMAGE_TYPE}" \
            -img "${IMAGE_NAME}" \
            -gpu "${GPU}" \
            -wait -json > "${log_file}"
    fi
    ccs_id="$("${JQ_CMD}" -r '.id' "${log_file}")"
    echo "CCS ID: ${ccs_id}"
    while [[ ! "${ccs_id}" =~ ^[0-9]+$ ]]; do
        if grep -q "\[TWCC-CLI\] Error" "${log_file}"; then
            cat "${log_file}"
            if grep -q "is not enabled" "${log_file}"; then
                echo "Requested resource (GPU) is not available!!! Please check the TWCC website for more details."
            fi
            echo "Please check the error message!!! Sleep for 1 minute ..."
            sleep 1m
        fi
        echo "(1) CCS ID is not valid, try to create a new one"
        if [[ -z "${container_name}" ]]; then
            "${TWCC_CLI_CMD}" mk ccs \
                -itype "${IMAGE_TYPE}" \
                -img "${IMAGE_NAME}" \
                -gpu "${GPU}" \
                -wait -json > "${log_file}"
        else
            "${TWCC_CLI_CMD}" mk ccs \
                -n "${container_name}" \
                -itype "${IMAGE_TYPE}" \
                -img "${IMAGE_NAME}" \
                -gpu "${GPU}" \
                -wait -json > "${log_file}"
        fi
        ccs_id="$("${JQ_CMD}" -r '.id' "${log_file}")"
        echo "(2) New CCS ID: ${ccs_id}"
    done
}

create_ccs() { # $1: ccs_log_file
    local log_file="$1"
    local port=""

    make_ccs "${log_file}"
    # <(...) process substitution, read SSH connect info into a Bash array "connect_info"
    read -r -a connect_info < <("${TWCC_CLI_CMD}" ls ccs -gssh -s "${ccs_id}")
    port="${connect_info[2]}" # port is the third element in $connect_info
    echo "PORT: ${port}"
    while [[ ! "${port}" =~ ^[0-9]+$ ]]; do
        echo "(1) PORT is not valid, try to kill the original CCS and create a new one"
        "${TWCC_CLI_CMD}" rm ccs -f -s "${ccs_id}"
        make_ccs "${log_file}"
        read -r -a connect_info < <("${TWCC_CLI_CMD}" ls ccs -gssh -s "${ccs_id}")
        port="${connect_info[2]}"
        echo "(2) New PORT: ${port}"
    done
}

check_processors() { # $1: ccs_log_file
    local log_file="$1"

    if [[ "${PREFERRED_SYSTEM_CPU_COUNT}" -eq 36 || "${PREFERRED_SYSTEM_CPU_COUNT}" -eq 56 ]]; then
        local tolerance_counter="${CPU_MATCH_TOLERANCE}"
        local cpu_count=""

        cpu_count="$(
            "${SSHPASS_CMD}" -p "${PASSWD}" \
                ssh -o StrictHostKeyChecking=no \
                "${connect_info[@]}" \
                'nproc --all'
        )"
        while [[ "${cpu_count}" -ne "${PREFERRED_SYSTEM_CPU_COUNT}" && "${tolerance_counter}" -gt 0 ]]; do
            echo "Step 2-1. CPU Num = ${cpu_count}, kill this container and create a new one"
            "${TWCC_CLI_CMD}" rm ccs -f -s "${ccs_id}"
            sleep 15s
            if [[ "${tolerance_counter}" -eq 1 ]]; then
                echo "Sleep for 20s"
                sleep 20s
            fi
            create_ccs "${log_file}"
            cpu_count="$(
                "${SSHPASS_CMD}" -p "${PASSWD}" \
                    ssh -o StrictHostKeyChecking=no \
                    "${connect_info[@]}" \
                    'nproc --all'
            )"
            tolerance_counter=$((tolerance_counter - 1)) # Use arithmetic expansion: $((EXPR)) 
        done
        if [[ "${cpu_count}" -ne "${PREFERRED_SYSTEM_CPU_COUNT}" ]]; then
            echo "...CPU Number of machine = ${cpu_count}, BAD!"
        else
            echo "...CPU Number of machine = ${cpu_count}, GOOD!"
        fi
    fi
}

wrap_command() { # $1: command
    local command="$1"
    local command_wrapped=""

    command="${command//\"/\\\"}" # escape double quotes in the command

    case "${TERMINAL_MULTIPLEXER}" in
        tmux)
            command_wrapped="tmux send-keys -t ${MULTIPLEXER_SESSION_NAME}:0 \"${command}\" C-m;"
            ;;
        screen)
            command_wrapped="screen -S ${MULTIPLEXER_SESSION_NAME} -p 0 -X stuff \"${command}^M\";"
            ;;
        *)
            command_wrapped=""
            ;;
    esac

    echo "${command_wrapped}"
}

combine_command() { # $1: line, $2: LINES_PER_ELEMENT, $3: start_line, $4: COMMAND_FILE
    local base_line="$1"
    local line_count="$2"
    local start_line="$3"
    local command_file="$4"

    local single_line_from_file=""
    local eof_flag=0
    local current_line=0

    commands_combined_within_element=""
    commands_combined_within_element_str=""
    container_name=""

    for (( current_line = start_line; current_line <= base_line + line_count - 1; current_line++ )); do
        # use sed to extract a specific line from the other script
        single_line_from_file="$(sed -n "${current_line}p" "${command_file}")"
        if [[ -z "${single_line_from_file}" ]]; then
            echo "=== Current line: ${current_line} ==="
            echo "# This line is empty."
            eof_flag=0
            continue
        elif [[ "${single_line_from_file}" =~ ^[[:space:]]*#[[:space:]]*@ ]]; then
            echo "=== Current line: ${current_line} ==="
            container_name="${single_line_from_file#*@}"
            container_name="${container_name%% *}"
            echo "# This line is a comment and contains the container name: '${container_name}'"
            if [[ ! "${container_name}" =~ ^[a-z][a-z0-9_-]{5,15}$ ]]; then
                echo "Container Name \"${container_name}\" is not valid, please check the format which should be ^[a-z][a-z0-9_-]{5,15}$ only."
                container_name=""
            fi
            continue
        elif [[ "${single_line_from_file}" =~ ^[[:space:]]*# ]]; then
            echo "=== Current line: ${current_line} ==="
            echo "# This line is a comment: ${single_line_from_file}"
            continue
        elif [[ "${single_line_from_file}" =~ ^[[:space:]]*END ]]; then
            echo "=== Current line: ${current_line} ==="
            echo "# The end of the file line is within this element."
            eof_flag=1
            break
        fi

        local wrapped=""
        wrapped="$(wrap_command "${single_line_from_file}")"
        commands_combined_within_element+="${wrapped} "
        commands_combined_within_element_str+="${single_line_from_file}; "
    done
    # Check next line for END
    current_line=$((current_line + 1))
    single_line_from_file="$(sed -n "${current_line}p" "${command_file}")"
    if [[ "${single_line_from_file}" =~ ^[[:space:]]*END ]]; then
        eof_flag=2
    fi

    return "${eof_flag}" # $eof_flag 0: "END" is not occur in the file, 1: emtpy lines after "END", 2: "END" is the last line of the file
}

#######################################
# Main
#######################################
mkdir -p "${LOG_DIR}"

case "${TERMINAL_MULTIPLEXER}" in
    tmux)
        multiplexer_new_session="tmux new -d -s ${MULTIPLEXER_SESSION_NAME};"
        multiplexer_kill_session="$(wrap_command "tmux kill-ses -t ${MULTIPLEXER_SESSION_NAME}")"
        ;;
    screen)
        multiplexer_new_session="screen -dmS ${MULTIPLEXER_SESSION_NAME};"
        multiplexer_kill_session="$(wrap_command "screen -X -S ${MULTIPLEXER_SESSION_NAME} quit")"
        ;;
    *)
        echo "Terminal multiplexer: ${TERMINAL_MULTIPLEXER} is not supported. Please use 'tmux' or 'screen'."
        exit
        ;;
esac

# Part 1. Common Commands
num_commands="$(wc -l < "${COMMON_COMMAND_FILE}")"
echo ">>>>> Number of COMMON commands: ${num_commands} <<<<<"
echo ""
combine_command 1 "${num_commands}" 1 "${COMMON_COMMAND_FILE}"
eof_flag=$?
common_commands_combined="${commands_combined_within_element}"
common_commands_combined_str="${commands_combined_within_element_str}"

if [[ -z "${common_commands_combined}" ]]; then
    echo "The common command is empty."
elif [[ "${eof_flag}" -eq 0 ]]; then
    echo "'END' does not occur in the common commands file. Please check if the format is valid."
    echo ">> Common commands: ${common_commands_combined_str}"
elif [[ "${eof_flag}" -eq 1 || "${eof_flag}" -eq 2 ]]; then
    echo ">> Common commands: ${common_commands_combined_str}"
fi
echo ""

# Part 2. Main Commands
echo "**************************************************"
num_commands="$(wc -l < "${COMMAND_FILE}")"
echo ">>>>> Number of MAIN commands: ${num_commands} <<<<<"
for (( line = COMMAND_START_LINE; line <= num_commands; line += LINES_PER_ELEMENT )); do
    start_line=$((line + LINES_SKIP_WITHIN_ELEMENT))
    echo ""
    echo "##### This Command Element Starts at Line: ${line} #####"
    combine_command "${line}" "${LINES_PER_ELEMENT}" "${start_line}" "${COMMAND_FILE}"
    eof_flag=$?
    if [[ "${eof_flag}" -eq 1 ]]; then
        echo "Program will exit right now!!!"
        break
    fi
    if [[ -z "${commands_combined_within_element}" && "${eof_flag}" -eq 2 ]]; then
        echo "No command to run in this element and next line after this element is the end of the file. Program will exit right now!!!"
        break
    elif [[ -z "${commands_combined_within_element}" ]]; then
        continue
    fi

    echo ">> Main commands: ${commands_combined_within_element_str}"

    if [[ "${container_index}" -ne 0 ]]; then
        echo "Step 0. Sleep for ${TIME_INTERVAL_BETWEEN_CONTAINERS}. (Time Interval Between Containers)"
        if [[ "${CHECK_MODE}" != true ]]; then
            sleep "${TIME_INTERVAL_BETWEEN_CONTAINERS}"
        fi
    fi
    
    echo "Step 1. Creating CCS"
    ccs_log_file="${LOG_DIR}/ccs_$(date +%y%m%d_%H%M%S)_Line${line}.log"
    if [[ -z "${container_name}" ]]; then
        if [[ -z "${DEFAULT_CONTAINER_NAME}" ]]; then
            container_name="ccs$(date +%y%m%dt%H%M%S)"
            echo "Set container name to current timestamp: ${container_name}"
        else
            container_name="${DEFAULT_CONTAINER_NAME}"
            echo "Set container name to default: ${container_name}"
        fi
    else
        echo "Container Name: ${container_name}"
    fi
    if [[ "${CHECK_MODE}" != true ]]; then
        create_ccs "${ccs_log_file}"
    fi

    echo "Step 2. Checking CCS"
    if [[ "${CHECK_MODE}" != true ]]; then
        check_processors "${ccs_log_file}"
    fi

    echo "Step 3. Run commands (common + main): ${common_commands_combined_str}${commands_combined_within_element_str}"
    delete_ccs_command="$(wrap_command "${TWCC_CLI_CMD_CONTAINER} rm ccs -f -s ${ccs_id}")"
    # ssh to remote and open a tmux session and run commmand in tmux session
    if [[ "${CHECK_MODE}" != true ]]; then
        "${SSHPASS_CMD}" -p "${PASSWD}" ssh -t -o "StrictHostKeyChecking=no" \
            "${connect_info[@]}" \
            "${multiplexer_new_session} ${common_commands_combined} ${commands_combined_within_element} ${delete_ccs_command} ${multiplexer_kill_session}"
    fi

    if [[ "${eof_flag}" -eq 2 ]]; then
        echo "The next line after this element is the end of the file. Program exits after running the commands in this element!!!"
        break
    fi
    container_index=$((container_index + 1))
done
