# TWCC Container Automation Tool

🌐 語言： 繁體中文 | [English](README.md)

![License](https://img.shields.io/badge/license-MIT-green)

本專案提供一個 **Bash 自動化腳本**，用於在 [**TWCC (Taiwan Computing Cloud)**](https://www.twcc.ai/) 上批次建立 CCS (Container Compute Service)，並透過 `tmux` 或 `screen` 在 CCS 遠端容器中執行預定義的指令流程，並於結束後自動刪除容器以釋放資源。

### 🚀 核心優勢

* **批次實驗管理**：一次性部署多個容器執行不同指令的實驗。
* **自動資源回收**：指令執行完畢後立即刪除 CCS，避免忘記關閉而產生高額費用。
* **無痛自動化**：將複雜的 CLI 與 SSH 操作封裝，只需維護指令檔即可管理流程。

---

## 📑 目錄

- [🤝 本專案與 TWCC CLI 的關係說明](#-本專案與-twcc-cli-的關係說明)
- [🔍 執行流程概念](#-執行流程概念)
- [🔧 環境需求](#-環境需求)
- [📖 使用步驟](#-使用步驟)
    - [Step 1️⃣. 專案初始化](#step-1️⃣-專案初始化)
    - [Step 2️⃣. 編輯 `setting.sh` 基本設定](#step-2️⃣-編輯-settingsh-基本設定)
    - [Step 3️⃣. 準備指令檔案](#step-3️⃣-準備指令檔案)
        - [📜 Common_Commands.sh](#-common_commandssh)
        - [📜 Commands.sh](#-commandssh)
    - [Step 4️⃣. 執行腳本](#step-4️⃣-執行腳本)
- [🔬 `setting.sh`進階功能設定](#-settingsh進階功能設定)
- [🚨 注意事項](#-注意事項)
- [📄 授權條款](#-授權條款)

---

## 🤝 本專案與 TWCC CLI 的關係說明

本專案並非重新實作 TWCC CCS 的容器管理機制，而是建立在 TWCC 官方提供的 Command Line Interface（CLI） 之上，透過 Bash script 將多個 CLI 指令流程化、自動化，用途在於將 CLI 指令依照實驗流程自動串接，以管理多組實驗指令與對應的 container 之批次執行與刪除。

本腳本中所有與 TWCC Container（CCS）生命週期相關的操作，皆是透過呼叫 TWCC CLI 指令完成，包括 `twccli mk ccs` （建立 CCS）、`twccli ls ccs -gssh` （取得 SSH 連線資訊）、`twccli rm ccs` （刪除 CCS）等。

如需瞭解 TWCC CLI 的完整指令說明與使用方式，請參考官方文件：
🔗 [TWCC Command Line Interface（CLI）官方說明文件](https://man.twcc.ai/@twccdocs/doc-cli-main-zh)

---

## 🔍 執行流程概念

1. **解析檔案**：依據預寫的指令檔切分指令區塊，每區塊可包含多個指令(利用 `LINES_PER_ELEMENT`設定指令數量)。
2. **建立容器**：自動建立 TWCC CCS（支援指定 Image / GPU 類型）。
3. **SSH 連線**：使用 `sshpass` 自動登入遠端環境。
4. **注入指令**：啟動 `tmux/screen` 並依序執行區塊內的指令。
5. **離線執行**：指令注入後，自動化腳本即完成任務並***結束運行***。本地機器***無需保持連線***，遠端容器會獨立在 `tmux/screen` 完成所有作業。
6. **自我回收**：任務結束後，容器內會自動下達 CCS 刪除指令進行自我刪除，確保資源不浪費。

---

## 🔧 環境需求

在執行腳本前，請確認您的**本地機器**（發送指令端）已安裝並設定好以下工具：

| 工具 | 用途 | 安裝參考指令 |
| :--- | :--- | :--- |
| **TWCC-CLI** | 官方容器管理工具 | `python -m pip install --no-user TWCC-CLI` |
| **jq** | 解析 JSON 資料 | `conda install jq -c conda-forge` |
| **sshpass** | 自動化處理 SSH 密碼輸入 | `conda install sshpass -c conda-forge` |

並確認您的**TWCC機器**（執行指令端/容器）已安裝並設定好以下工具：

| 工具 | 用途 | 安裝參考指令 |
| :--- | :--- | :--- |
| **TWCC-CLI** | 官方容器管理工具 | `python -m pip install --no-user TWCC-CLI` |
| **tmux/screen** | 遠端容器內的終端多工器 | `sudo apt install tmux/screen` |

> [!IMPORTANT]
> 📢 針對TWCC-CLI工具，開始前請務必先完成 [官方登入設定](https://man.twcc.ai/@twccdocs/guide-cli-signin-zh)。

---

## 📖 使用步驟

### Step 1️⃣. 專案初始化

```bash
git clone https://github.com/jefferykho/twcc-container-automation-tool.git
cd twcc-container-automation-tool

# 建立密碼檔 (強烈建議不要將此檔案 commit 到 GitHub)
printf '%s\n' '#!/bin/bash' '' 'PASSWD="TWCC_Machine_Password"' > password.sh
mkdir -p ./LOG/
```

執行完畢後請確認目錄結構如下：

```text
.
├── container_batch_runner.sh  # 本自動化腳本
├── password.sh                # TWCC機器登入密碼設定
├── setting.sh                 # 參數設定
├── Commands/
│   ├── Common_Commands.sh     # 共用指令（每個 CCS 都會執行）
│   └── Commands.sh            # 個別化指令（分 Element 執行）
├── LOG/                       # 自動產生，用於儲存 CCS log
├── .gitignore
├── LICENSE
├── README.md
└── README.zh-TW.md
```

並確認 `password.sh` 檔案中，`PASSWD`引號內的值為您TWCC機器正確的「登入密碼」

---

### Step 2️⃣. 編輯 `setting.sh` 基本設定

```bash
# 套件路徑
TWCC_CLI_CMD="$HOME/miniconda3/envs/<env_name>/bin/twccli"
SSHPASS_CMD="$HOME/miniconda3/envs/<env_name>/bin/sshpass"
JQ_CMD="$HOME/miniconda3/envs/<env_name>/bin/jq"
TWCC_CLI_CMD_CONTAINER="~/miniconda3/envs/<env_name>/bin/twccli" 
# 映像檔設定
IMAGE_TYPE="Custom Image"
IMAGE_NAME="Your TWCC Image Name"
# 容器配置
GPU="1m" # 1/2/4/8/1m/2m/4m/8m
DEFAULT_CONTAINER_NAME="containername"
TERMINAL_MULTIPLEXER="tmux" # tmux/screen
# 批次邏輯
LINES_PER_ELEMENT=5
# 預演模式
CHECK_MODE=false # false/true
```

**套件路徑**：在 `TWCC_CLI_CMD`、`SSHPASS_CMD`、`JQ_CMD` 分別填入您**本地機器**的`twccli`、`sshpass`、`jq`套件路徑，並在 `TWCC_CLI_CMD_CONTAINER` 填入您 **TWCC 機器**的 `twccli` 套件路徑。
> [!NOTE]
> 🔔 若您的 `twccli` / `sshpass` / `jq` 不在 conda 環境中，請改為實際安裝路徑。可在命令列使用 `which twccli/sshpass/jq` 等指令查詢安裝路徑。

**映像檔設定**：在 `IMAGE_TYPE` 填入預計建立的CCS容器映像檔類型（如：TensorFlow, PyTorch, Custom Image 等），並在 `IMAGE_NAME` 填入預計建立的 CCS 容器使用的映像檔版本。
> [!TIP]
> 🔑 可使用 `twccli ls ccs -itype` 指令查詢當前可用的映像檔類型，並使用 `twccli ls ccs -itype "IMAGE_TYPE" -img` 指令查詢特定映像檔類型下可用的映像檔版本。

**容器配置**：在 `GPU` 依需求調整數量型號（如`1`,`2`,`4`,`8`,`1m`,`2m`,`4m`,`8m`等，帶有後綴 `m` 為具有共享記憶體的 GPU 型號）。在 `DEFAULT_CONTAINER_NAME` 設定欲建立的 CCS 容器的預設名稱。另外，依終端多工器需求將 `TERMINAL_MULTIPLEXER` 調整為 `tmux` 或 `screen`。

**批次邏輯**：**`LINES_PER_ELEMENT`** 參數定義了每次建立一個 CCS 容器時，會從 `Commands.sh` 檔案讀取幾行指令來執行，故此參數需依照 `Commands.sh` 中每個區塊的行數來設定。（詳見Step 3之說明。）

**預演模式**：建議先將 `CHECK_MODE` 設為 `true` 開啟 dry-run 模式進行測試。此模式執行腳本時只會讀取指令，不實際建立 CCS 容器，用以確保指令讀取與預期相符。

---

### Step 3️⃣. 準備指令檔案

本專案將指令分為兩類：
1. **`Common_Commands.sh`**：每個 CCS 容器都會預先執行的**共同**初始化指令（例如環境設定`conda activate`、變更資料夾路徑）。
2. **`Commands.sh`**：主要指令區塊，分別定義每個 CCS 容器要執行的**個別化**指令。

以下是其分別的格式範例：

#### 📜 Common_Commands.sh

```bash
cd ~/gpu-burn
conda activate base
END         # <-- (必要) 告知腳本在此停止
```

**📝 規則說明：**

**一行一指令**：此腳本會視每一「行」為一單一指令，因此請務必將單一指令濃縮在一行內，勿使用跨行指令，否則將會造成指令注入失敗！

**END 結束關鍵字（必要）**：`END` 必須出現在所有欲執行指令的最後，用於告知 script 停止解析。

#### 📜 Commands.sh

```bash
# @containername1       # <-- (選填) 定義容器名稱
# run GPU for 20 seconds
./gpu_burn 20
# run GPU for 20 seconds
./gpu_burn 20
# Don't want to set name for container2
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
END                     # <-- (必要) 告知腳本在此停止
```

**📝 規則說明：**

**一行一指令**：此腳本會視每一「行」為一單一指令，因此請務必將單一指令濃縮在一行內，勿使用跨行指令，否則將會造成指令注入失敗！

**指令區塊（Element）**：每一個指令區塊「Element」由 `LINES_PER_ELEMENT` 行組成，每個 Element 對應一個 CCS 容器，該 Element 內的所有指令，會在同一個 CCS 容器、同一個 `tmux/screen` session 中依序執行。例如：此範例中的 `LINES_PER_ELEMENT` 需設置為 5，代表每次建立一個 CCS 容器會讀取 5 行，CCS 容器開啟後會依序執行這 5 行中的指令。

**容器名稱標註（可選）**：使用 `# @容器名稱` 格式，例如以上範例的：`# @containername1`、`# @containername3`、`# @containername4`，該名稱會被用作 TWCC CCS 容器名稱的設定。若未提供（例如以上範例的第二個Element），則會使用 `setting.sh` 中的 `DEFAULT_CONTAINER_NAME` 或當下的時間戳（`DEFAULT_CONTAINER_NAME`為空時）當作 CCS 容器的名稱。
> [!CAUTION]
> ⚠️ CCS 容器名稱命名須遵守「由小寫英文字母或數字組成，並介於6~16個字元之間，且第一個字須為英文字母」(`^[a-z][a-z0-9_-]{5,15}$`)的規則。 

**註解行或空白行**：純註解行會被忽略，因此若不同的 CCS 容器所預計執行的指令行數不同，可將 `LINES_PER_ELEMENT` 設為其中最大的指令行數，並藉由適當的空白行或註解行來填補 Element 內的空白處。

**避免事項**：請避免指令區塊內包含的指令長度過長且過多，若有需求，建議將指令封裝成 `.sh` 檔放在 TWCC 機器內再由本腳本呼叫，否則將會造成指令注入時的指令異常截斷。

**END 結束關鍵字（必要）**：`END` 關鍵字必須出現在欲執行的所有指令的最後，用於告知自動化腳本停止解析及讀取。若 `END` 關鍵字在某 Element 中出現，腳本會於該 Element 後停止執行。若缺少 `END` 關鍵字，腳本會警告格式錯誤。

---

### Step 4️⃣. 執行腳本

```bash
bash container_batch_runner.sh
```

---

## 🔬 `setting.sh`進階功能設定

#### 指令檔相關設定

```bash
COMMON_COMMAND_FILE="Commands/Common_Commands.sh"
COMMAND_FILE="Commands/Commands.sh"
COMMAND_START_LINE=1
LINES_SKIP_WITHIN_ELEMENT=0
```

* `COMMON_COMMAND_FILE`：共同指令檔路徑，每次建立 CCS 都會先執行的指令
* `COMMAND_FILE`：主要指令檔路徑，**以 Element 為單位**分別建立 CCS 容器執行
* `COMMAND_START_LINE`：主要指令檔的起始行，可設定為特定行數，則腳本會從該行開始讀取指令並執行。預設值為 1，即從頭執行。
* `LINES_SKIP_WITHIN_ELEMENT`：若有特定需求，需讓腳本在每個 Element 內略過前幾行不執行，可設定此參數。預設值為 0，表示不略過任何指令。

#### 終端機多工器設定

```bash
TERMINAL_MULTIPLEXER="tmux" # tmux / screen
MULTIPLEXER_SESSION_NAME="0"
```

* `TERMINAL_MULTIPLEXER`：指定使用的終端機多工器為 `tmux` 或 `screen`
* `MULTIPLEXER_SESSION_NAME`：指定多工器會話名稱，預設值為 "0"。

#### 機器CPU相關設定

```bash
PREFERRED_SYSTEM_CPU_COUNT=None # None / 36 / 56
CPU_MATCH_TOLERANCE=2
```

* `PREFERRED_SYSTEM_CPU_COUNT`：若設定為 `36` 或 `56`，會檢查容器機器的CPU是總數為36核的型號或56核的型號，若不符，會嘗試刪除並重新建立 CCS。預設值為 `None`，即不檢查。
* `CPU_MATCH_TOLERANCE`：若 CPU 型號不符，重新建立 CCS 容器的最多反覆次數，若超過此值，就算 CPU 型號不符也不會再嘗試重新建立。
> [!NOTE]
> 📢 不論CPU型號為總數36核版本或總數56核版本，每一單位GPU固定是分配到CPU的4核心。

#### 其他設定

```bash
TIME_INTERVAL_BETWEEN_CONTAINERS=0   # 0 / 1s / 1m
LOG_DIR="./LOG/"
```

* `TIME_INTERVAL_BETWEEN_CONTAINERS`：指定建立 CCS 容器之間的間隔時間，若需要在每建立一個 CCS 容器後登入 double check，可以設定非零值(例如：1m(一分鐘))，減慢自動化腳本建立容器的速度。
* `LOG_DIR`：設定建立 CCS 容器時產生的LOG檔存檔路徑。

---

## 🚨 注意事項

1. **安全性**：`password.sh` 包含敏感資訊，請確保其檔案權限且**切勿上傳至公開倉儲**。
2. **資源配額與可用性**：請確認 TWCC 資源配額充足，若 GPU 資源不足，腳本可能會多次重試。
3. **異常處理**：若腳本異常終止，請務必手動登入 TWCC 網頁或使用 `twccli ls ccs` 指令確認容器是否已刪除，避免持續計費。

---

## 📄 授權條款

本專案採用 MIT License 授權，詳見 [`LICENSE`](LICENSE) 檔案。
