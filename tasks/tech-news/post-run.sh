#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

echo "[post-run] tech-news の事後処理（Slack送信）を開始します..."

# タスクが失敗した場合は送信しない（またはエラー通知）
if [[ "${TASK_EXIT_CODE:-0}" -ne 0 ]]; then
  echo "[post-run] [WARN] タスクがエラー終了したため、Slack への成果物送信をスキップします (ExitCode: ${TASK_EXIT_CODE:-0})。"
  exit 0
fi

REPORT_FILE="${SCRIPT_DIR}/report.md"

# report.md が存在しない場合は最新のログファイルを探索
if [[ ! -f "${REPORT_FILE}" ]]; then
  LOG_FILE="${PROJECT_ROOT}/logs/tech-news/routine-$(date +'%Y%m%d').log"
  if [[ -f "${LOG_FILE}" ]]; then
    echo "[post-run] report.md が見つからないため、本日のログファイルから送信します: ${LOG_FILE}"
    REPORT_FILE="${LOG_FILE}"
  else
    echo "[post-run] [ERROR] 送信対象のレポートファイルが見つかりません。"
    exit 1
  fi
fi

# TypeScript スクリプトを実行して Slack へ送信
cd "${PROJECT_ROOT}"
node --experimental-strip-types scripts/send-slack.ts "${REPORT_FILE}"

echo "[post-run] Slack 送信処理が完了しました。"
