#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 引数チェック
TASK_NAME="${1:-}"
if [[ -z "${TASK_NAME}" ]]; then
  echo "[ERROR] タスク名が指定されていません。使用方法: $0 <task-name>" >&2
  exit 1
fi

TASK_DIR="${PROJECT_ROOT}/tasks/${TASK_NAME}"
if [[ ! -d "${TASK_DIR}" ]]; then
  echo "[ERROR] 指定されたタスクディレクトリが見つかりません: ${TASK_DIR}" >&2
  exit 1
fi

# デフォルト設定値
EFFORT="medium"
TIMEOUT=600
ENABLED="true"

# task.conf の読み込み
CONFIG_FILE="${TASK_DIR}/task.conf"
if [[ -f "${CONFIG_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"
fi

# 無効化されている場合は終了
if [[ "${ENABLED}" != "true" ]]; then
  echo "[INFO] タスク '${TASK_NAME}' は ENABLED=false のためスキップされました。"
  exit 0
fi

# prompt.md の存在確認と読み込み
PROMPT_FILE="${TASK_DIR}/prompt.md"
if [[ ! -f "${PROMPT_FILE}" ]]; then
  echo "[ERROR] 指示書ファイルが見つかりません: ${PROMPT_FILE}" >&2
  exit 1
fi
PROMPT_CONTENT="$(cat "${PROMPT_FILE}")"

# .env があれば環境変数をロード
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
  # shellcheck disable=SC1091
  source "${PROJECT_ROOT}/.env"
fi

# PATH解決 (mise shims, ~/.local/bin 等)
export PATH="${HOME}/.local/share/mise/shims:${HOME}/.local/bin:${PATH}"

AGY_BIN="$(command -v agy || true)"
if [[ -z "${AGY_BIN}" ]]; then
  echo "[ERROR] agy CLI が見つかりません。PATH設定を確認してください。" >&2
  exit 1
fi

# ログディレクトリ設定 (タスクごとにサブディレクトリを分離)
LOG_DIR="${PROJECT_ROOT}/logs/${TASK_NAME}"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/routine-$(date +'%Y%m%d').log"

echo "========================================================" | tee -a "${LOG_FILE}"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Antigravity Task: ${TASK_NAME}" | tee -a "${LOG_FILE}"
echo "Task Dir: ${TASK_DIR}" | tee -a "${LOG_FILE}"
echo "Effort: ${EFFORT}" | tee -a "${LOG_FILE}"
echo "========================================================" | tee -a "${LOG_FILE}"

cd "${PROJECT_ROOT}"

# 事前処理フック (pre-run.sh) があれば実行
PRE_RUN_HOOK="${TASK_DIR}/pre-run.sh"
if [[ -x "${PRE_RUN_HOOK}" ]]; then
  echo "[INFO] Executing pre-run hook..." | tee -a "${LOG_FILE}"
  "${PRE_RUN_HOOK}" 2>&1 | tee -a "${LOG_FILE}" || true
fi

# agy -p (printモード) で非対話実行
set +e
"${AGY_BIN}" -p "${PROMPT_CONTENT}" \
  --dangerously-skip-permissions \
  --effort "${EFFORT}" \
  2>&1 | tee -a "${LOG_FILE}"
EXIT_CODE=${PIPESTATUS[0]}
set -e

# 事後処理フック (post-run.sh) があれば実行
POST_RUN_HOOK="${TASK_DIR}/post-run.sh"
if [[ -x "${POST_RUN_HOOK}" ]]; then
  echo "[INFO] Executing post-run hook..." | tee -a "${LOG_FILE}"
  TASK_EXIT_CODE="${EXIT_CODE}" "${POST_RUN_HOOK}" 2>&1 | tee -a "${LOG_FILE}" || true
fi

echo "--------------------------------------------------------" | tee -a "${LOG_FILE}"
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Task '${TASK_NAME}' completed successfully." | tee -a "${LOG_FILE}"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Task '${TASK_NAME}' failed with exit code ${EXIT_CODE}." | tee -a "${LOG_FILE}"
fi
echo "========================================================" | tee -a "${LOG_FILE}"

exit ${EXIT_CODE}
