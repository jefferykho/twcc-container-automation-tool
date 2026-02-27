# TWCC Container Automation Tool

🌐 Language: English | [繁體中文](README.zh-TW.md)

![License](https://img.shields.io/badge/license-MIT-green)

This project provides a **Bash automation script** designed for [**TWCC (Taiwan Computing Cloud)**](https://www.twcc.ai/). It enables batch deployment of CCS (Container Compute Service) instances, executes predefined workflows inside remote containers using `tmux` or `screen`, and automatically deletes containers upon task completion to release resources.

### 🚀 Key Features

* **Batch Experiment Management**: Deploy multiple containers at once to run experiments with different command sets.
* **Automatic Resource Recycling**: Delete CCS instances automatically after tasks finish to prevent unnecessary charges.
* **Seamless Automation**: Encapsulate complex CLI and SSH operations into a single script. Simply maintain your command files to manage the entire workflow.

---

## 📑 Table of Contents

- [🤝 Relationship with TWCC CLI](#-relationship-with-twcc-cli)
- [🔍 Workflow Overview](#-workflow-overview)
- [🔧 Prerequisites](#-prerequisites)
- [📖 Usage Guide](#-usage-guide)
    - [Step 1️⃣: Project Initialization](#step-1️⃣-project-initialization)
    - [Step 2️⃣: Edit `setting.sh`](#step-2️⃣-edit-settingsh)
    - [Step 3️⃣: Prepare Command Files](#step-3️⃣-prepare-command-files)
        - [📜 Example: `Common_Commands.sh`](#-example-common_commandssh)
        - [📜 Example: `Commands.sh`](#-example-commandssh)
    - [Step 4️⃣: Run the Script](#step-4️⃣-run-the-script)
- [🔬 Advanced Settings (`setting.sh`)](#-advanced-settings-settingsh)
- [🚨 Important Notes](#-important-notes)
- [📄 License](#-license)

---

## 🤝 Relationship with TWCC CLI

This project does **not** reimplement the TWCC CCS management mechanism. Instead, it is built on top of the official **TWCC Command Line Interface (CLI)**. It uses a Bash script to orchestrate and automate multiple CLI commands, enabling batch execution and automatic deletion of containers for various experimental setups.

All lifecycle operations related to TWCC Container (CCS) instances are performed by calling official TWCC CLI commands, such as `twccli mk ccs` (create), `twccli ls ccs -gssh` (get SSH info), and `twccli rm ccs` (delete).

For detailed information about TWCC CLI, please refer to the official documentation:
🔗 [TWCC Command Line Interface (CLI) Official Document](https://man.twcc.ai/@twccdocs/doc-cli-main-zh)

---

## 🔍 Workflow Overview

1. **File Parsing**: Split the user-defined command file into "Elements" (blocks). Each block contains a fixed number of commands, configurable via `LINES_PER_ELEMENT`.
2. **Container Creation**: Automatically launch containers with the specified image and GPU configuration.
3. **SSH Connection**: Use `sshpass` for automated remote login.
4. **Command Injection**: Start a `tmux` or `screen` session and execute the commands in the block sequentially.
5. **Detached Execution**: Once commands are injected, the automation script completes and ***terminates***. Your local machine ***does not need to stay connected***. The remote container continues execution independently inside the `tmux` or `screen` session.
6. **Self-Deletion**: After all tasks are finished, the container issues a CCS deletion command internally to remove itself, ensuring no budget is wasted.

---

## 🔧 Prerequisites

Make sure your **local machine** (where the automation script runs) has the following tools installed and configured:

| Tool | Purpose | Installation Example |
|------|---------|----------------------|
| **TWCC-CLI** | Official container management tool | `python -m pip install --no-user TWCC-CLI` |
| **jq** | JSON parser | `conda install jq -c conda-forge` |
| **sshpass** | Automate SSH password entry | `conda install sshpass -c conda-forge` |

Also ensure your **TWCC machine** (the container environment) has the following tools installed and configured:

| Tool | Purpose | Installation Example |
|------|----------|----------------------|
| **TWCC-CLI** | Official container management tool | `python -m pip install --no-user TWCC-CLI` |
| **tmux/screen** | Terminal multiplexer | `sudo apt install tmux` or `sudo apt install screen` |

> [!IMPORTANT]
> 📢 Before starting, you must complete the [Official Login Configuration](https://man.twcc.ai/@twccdocs/guide-cli-signin-zh) for TWCC-CLI.

---

## 📖 Usage Guide

### Step 1️⃣: Project Initialization

```bash
git clone https://github.com/jefferykho/twcc-container-automation-tool.git
cd twcc-container-automation-tool

# Create the password file (DO NOT commit this file to GitHub)
printf '%s\n' '#!/bin/bash' '' 'PASSWD="TWCC_Machine_Password"' > password.sh
mkdir -p ./LOG/
```

After initialization, verify your directory structure:

```text
.
├── container_batch_runner.sh  # Main automation script
├── password.sh                # TWCC machine login password (User-created)
├── setting.sh                 # Parameter configurations
├── Commands/
│   ├── Common_Commands.sh     # Shared commands (run by every CCS)
│   └── Commands.sh            # Individual commands (per Element)
├── LOG/                       # Auto-generated logs
├── .gitignore
├── LICENSE
├── README.md
└── README.zh-TW.md
```

Make sure the `PASSWD` field in `password.sh` is correctly set to your TWCC machine login password.

---

### Step 2️⃣: Edit `setting.sh`

```bash
# Tool Paths
TWCC_CLI_CMD="$HOME/miniconda3/envs/<env_name>/bin/twccli"          # (local machine)
SSHPASS_CMD="$HOME/miniconda3/envs/<env_name>/bin/sshpass"          # (local machine)
JQ_CMD="$HOME/miniconda3/envs/<env_name>/bin/jq"                    # (local machine)
TWCC_CLI_CMD_CONTAINER="~/miniconda3/envs/<env_name>/bin/twccli"    # (TWCC machine)
# Image Configuration
IMAGE_TYPE="Custom Image"
IMAGE_NAME="Your TWCC Image Name"
# Container Configuration
GPU="1m" # Options: 1/2/4/8/1m/2m/4m/8m
DEFAULT_CONTAINER_NAME="containername"
TERMINAL_MULTIPLEXER="tmux" # tmux / screen
# Batch Logic
LINES_PER_ELEMENT=5
# Dry-Run Mode
CHECK_MODE=false # false / true
```

**Tool Paths**: Set `TWCC_CLI_CMD`, `SSHPASS_CMD`, and `JQ_CMD` to the installation paths of `twccli`, `sshpass`, and `jq` on your **local machine**, and set `TWCC_CLI_CMD_CONTAINER` to the installation path of `twccli` on your **TWCC machine (container)**.
> [!NOTE]
> 🔔 If these tools are not installed in a Conda environment, adjust the paths accordingly. Use `which twccli`, `which sshpass`, or `which jq` to locate your installation paths.

**Image Configuration**: Specify the CCS `IMAGE_TYPE` (e.g., TensorFlow, PyTorch, Custom Image) and the exact `IMAGE_NAME` (specific image version).
> [!TIP]
> 🔑 Use `twccli ls ccs -itype` to inspect available images types, and `twccli ls ccs -itype "TYPE" -img` for specific images versions.

**Container Configuration**: Specify the `GPU` count/type. (e.g., `1`, `2`, `4`, `8`, `1m`, `2m`, `4m` ,`8m`) The `m` suffix indicates GPU models with shared memory. Set a `DEFAULT_CONTAINER_NAME` for default name of the created CCS container. Choose between `tmux` or `screen` for `TERMINAL_MULTIPLEXER`.

**Batch Logic**: **`LINES_PER_ELEMENT`** defines how many lines are read from `Commands.sh` for each container to execute. This must match your command "Element" (block) structure (see Step 3).

**Dry-Run Mode**: It is recommended to set `CHECK_MODE=true` initially to enable dry-run mode. This reads the commands without actually creating CCS containers to ensure the logic is correct.

---

### Step 3️⃣: Prepare Command Files

This project uses two types of command files:
1. **`Common_Commands.sh`**: Executed by **every CCS container** before the main commands, providing shared initialization steps (e.g., `conda activate`, `cd` into a directory).
2. **`Commands.sh`**: Executed **per CCS container** to run the main command blocks, defining the specific commands for each CCS instance.

#### 📜 Example: `Common_Commands.sh`

```bash
cd ~/gpu-burn
conda activate base
END         # <-- (Mandatory) Signals the script to stop parsing here
```

**📝 Rules：**

**One Command Per Line**: The script treats each line as a single command. Multi-line commands are **NOT** supported.

**END Keyword**: The `END` keyword must appear at the very end of your command list. The script will stop parsing once it hits `END`.

#### 📜 Example: `Commands.sh`

```bash
# @containername1       # <-- (Optional) Define a specific container name
# run GPU for 20 seconds
./gpu_burn 20
# run GPU for 20 seconds
./gpu_burn 20
# No name set for this block (will use default/timestamp)
# run GPU for 20 seconds
./gpu_burn 20
# run GPU for 20 seconds
./gpu_burn 20
# @containername3
./gpu_burn 20
./gpu_burn 20


# @containername4
./gpu_burn 10
./gpu_burn 10
./gpu_burn 10
./gpu_burn 20
END                     # <-- (Mandatory) Signals the script to stop parsing
```

**📝 Rules：**

**One Command Per Line**: The script treats each line as a single command. Do **NOT** use multi-line commands, as it will break the injection process.

**Command Blocks/Elements**: Each block consists of `LINES_PER_ELEMENT` lines. Each block corresponds to one CCS container. All commands in a block run sequentially in the same `tmux/screen` session.

**Container Naming (Optional)**: Use `# @Name` annotation to assign a custom container name. If not specified, the script uses `DEFAULT_CONTAINER_NAME` or a timestamp (if default is empty) for the name of created container.
> [!CAUTION]
> ⚠️ Container names must be **6-16 characters**, lowercase letters or numbers, and start with a letter (follow: `^[a-z][a-z0-9_-]{5,15}$`).

**Comments and Blank Lines**: Pure comment lines and blank lines are ignored. You can use blank lines or comments to pad blocks if different containers require different numbers of commands.

**Avoid Long Commands**: If commands are excessively long, wrap them into a `.sh` file on the TWCC machine and call that script instead to avoid truncation issues.

**END Keyword**: The `END` keyword must appear at the very end of your command list. The script will stop parsing once it hits `END`.

---

### Step 4️⃣: Run the Script

```bash
bash container_batch_runner.sh
```

---

## 🔬 Advanced Settings (`setting.sh`)

#### Command File & Parsing Logic

```bash
COMMON_COMMAND_FILE="Commands/Common_Commands.sh"
COMMAND_FILE="Commands/Commands.sh"
COMMAND_START_LINE=1
LINES_SKIP_WITHIN_ELEMENT=0
```

* `COMMON_COMMAND_FILE`: Path to the shared initialization command file.
* `COMMAND_FILE`: Path to the main batch command file.
* `COMMAND_START_LINE`: The line number to start reading from in `Commands.sh`. The default value is 1, meaning the execution starts from the very beginning.
* `LINES_SKIP_WITHIN_ELEMENT`: If needed, this parameter specifies the number of initial lines to skip within each Element. The default value is 0, meaning no lines are skipped.

#### Terminal Multiplexer

```bash
TERMINAL_MULTIPLEXER="tmux" # tmux / screen
MULTIPLEXER_SESSION_NAME="0"
```

* `TERMINAL_MULTIPLEXER`: Choose `tmux` or `screen`.
* `MULTIPLEXER_SESSION_NAME`: The name of the multiplexer session (Default: "0").

#### CPU Specifics

```bash
PREFERRED_SYSTEM_CPU_COUNT=None # None / 36 / 56
CPU_MATCH_TOLERANCE=2
```

* `PREFERRED_SYSTEM_CPU_COUNT`: If set to `36` or `56`, the script ensures that the container host corresponds to the intended CPU model, where `36` and `56` represent 36-core and 56-core processor models respectively. Otherwise, it deletes and recreates the CCS instance (up to `CPU_MATCH_TOLERANCE` retries).
* `CPU_MATCH_TOLERANCE`: Maximum number of retries allowed if the container host does not match the specified CPU model (e.g., 36-core or 56-core).
> [!NOTE]
> 📢 Each GPU unit is allocated 4 CPU cores, regardless of whether the host is a 36-core or 56-core CPU model.

#### Other Settings

```bash
TIME_INTERVAL_BETWEEN_CONTAINERS=0 # 0 / 1s / 1m
LOG_DIR="./LOG/"
```

* `TIME_INTERVAL_BETWEEN_CONTAINERS`: Delay between container creation (e.g., `1m` for 1 minute). Useful if you need to manually check instances during deployment.
* `LOG_DIR`: Directory where CCS creation logs are stored.

---

## 🚨 Important Notes

1. **Security**: `password.sh` contains sensitive credentials. Restrict file permissions and **never upload it to a public repository**.
2. **Resource Quota**: Ensure sufficient TWCC GPU/CPU quotas. The script may retry if resources are unavailable.
3. **Error Handling**: If the script terminates unexpectedly, manually check the TWCC dashboard or use `twccli ls ccs` to verify if containers were deleted to avoid unexpected charges.

---

## 📄 License

This project is licensed under the MIT License.
See the [`LICENSE`](LICENSE) file for details.
