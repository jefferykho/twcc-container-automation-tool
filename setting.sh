#!/bin/bash

### Local Machine Settings ###
TWCC_CLI_CMD="$HOME/miniconda3/envs/<env_name>/bin/twccli" # Please fill in the twccli path in your local machine
SSHPASS_CMD="$HOME/miniconda3/envs/<env_name>/bin/sshpass" # Please fill in the sshpass path in your local machine
JQ_CMD="$HOME/miniconda3/envs/<env_name>/bin/jq" # Please fill in the jq path in your local machine

### TWCC Container Settings ###
TWCC_CLI_CMD_CONTAINER="~/miniconda3/envs/<env_name>/bin/twccli"
IMAGE_TYPE="Custom Image"
IMAGE_NAME="Your TWCC Image Name" # Please fill in the image name you want to use
PREFERRED_SYSTEM_CPU_COUNT=None # None/36/56
CPU_MATCH_TOLERANCE=2
GPU="1m" # Options: 1/2/4/8/1m/2m/4m/8m
DEFAULT_CONTAINER_NAME="containername"
TERMINAL_MULTIPLEXER="tmux" # tmux/screen
MULTIPLEXER_SESSION_NAME="0"
TIME_INTERVAL_BETWEEN_CONTAINERS="0" # 0/1s/1m

### Command Scripts Settings ###
LOG_DIR="./LOG/"
COMMON_COMMAND_FILE="Commands/Common_Commands.sh"
COMMAND_FILE="Commands/Commands.sh"
COMMAND_START_LINE=1
LINES_PER_ELEMENT=5 # Defines how many lines are read from COMMAND_FILE for each container to execute
LINES_SKIP_WITHIN_ELEMENT=0

CHECK_MODE=false # false/true
