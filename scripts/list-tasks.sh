#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "========================================================================================="
echo " Antigravity 定期実行タスク一覧 (tasks/)"
echo "========================================================================================="
printf "%-25s | %-10s | %-24s | %-10s\n" "タスク名" "状態" "スケジュール (OnCalendar)" "思考レベル"
echo "-----------------------------------------------------------------------------------------"

for TASK_DIR in "${PROJECT_ROOT}/tasks"/*; do
  if [[ ! -d "${TASK_DIR}" ]]; then
    continue
  fi

  TASK_NAME="$(basename "${TASK_DIR}")"
  if [[ "${TASK_NAME}" =~ ^_ ]]; then
    continue
  fi

  CONFIG_FILE="${TASK_DIR}/task.conf"
  SCHEDULE="未設定"
  EFFORT="medium"
  ENABLED="不明"

  if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
  fi

  STATUS_STR="[無効]"
  if [[ "${ENABLED}" == "true" ]]; then
    STATUS_STR="[有効]"
  fi

  printf "%-25s | %-10s | %-24s | %-10s\n" "${TASK_NAME}" "${STATUS_STR}" "${SCHEDULE}" "${EFFORT}"
done

echo "========================================================================================="
echo ""
echo "■ systemd 側のアクティブタイマー稼働状況:"
echo ""
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user list-timers "agy-task-*" --no-pager || echo "（稼働中の agy-task タイマーはありません）"
else
  echo "systemctl コマンドが利用できません。"
fi
echo ""
