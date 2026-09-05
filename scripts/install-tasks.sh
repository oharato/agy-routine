#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

echo "=========================================================="
echo " [INFO] Antigravity マルチタスク定期実行のセットアップ開始"
echo "=========================================================="

mkdir -p "${SYSTEMD_USER_DIR}"

# 1. 共通テンプレートサービスの配置
echo "[1/3] 共通テンプレートサービス (agy-task@.service) を配置..."
cp "${PROJECT_ROOT}/systemd/agy-task@.service" "${SYSTEMD_USER_DIR}/agy-task@.service"

# 2. tasks/ 配下の各タスクのタイマー生成
echo "[2/3] tasks/ 配下の各タスクをスキャンしてタイマーを生成..."

INSTALLED_COUNT=0
for TASK_DIR in "${PROJECT_ROOT}/tasks"/*; do
  if [[ ! -d "${TASK_DIR}" ]]; then
    continue
  fi

  TASK_NAME="$(basename "${TASK_DIR}")"

  # '_' 始まり (例: _template) はスキップ
  if [[ "${TASK_NAME}" =~ ^_ ]]; then
    continue
  fi

  CONFIG_FILE="${TASK_DIR}/task.conf"
  if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "  [WARN] ${TASK_NAME} に task.conf が無いためスキップします。"
    continue
  fi

  # 設定のロード
  SCHEDULE="Mon..Fri *-*-* 09:00:00"
  ENABLED="true"
  # shellcheck disable=SC1090
  source "${CONFIG_FILE}"

  TIMER_FILE="${SYSTEMD_USER_DIR}/agy-task-${TASK_NAME}.timer"
  cat << TIMER_EOF > "${TIMER_FILE}"
[Unit]
Description=Antigravity Routine Timer: ${TASK_NAME}

[Timer]
OnCalendar=${SCHEDULE}
Persistent=true
Unit=agy-task@${TASK_NAME}.service

[Install]
WantedBy=timers.target
TIMER_EOF

  echo "  - タスク: ${TASK_NAME}"
  echo "    スケジュール: ${SCHEDULE}"
  echo "    タイマーファイル: ${TIMER_FILE}"
  INSTALLED_COUNT=$((INSTALLED_COUNT + 1))
done

# 3. systemd のリロードとタイマー適用
echo "[3/3] systemd ユーザーデーモンのリロードとタイマー適用..."

HAS_DBUS=true
if ! systemctl --user daemon-reload >/dev/null 2>&1; then
  HAS_DBUS=false
  echo "  [WARN] 現在のセッションから systemd user bus への接続ができませんでした。"
  echo "         (ユニットファイルは正常に生成・配置されています)"
  echo "         SSH ログイン端末から 'systemctl --user daemon-reload' を実行してください。"
fi

if [[ "${HAS_DBUS}" == "true" ]]; then
  for TASK_DIR in "${PROJECT_ROOT}/tasks"/*; do
    if [[ ! -d "${TASK_DIR}" ]]; then
      continue
    fi
    TASK_NAME="$(basename "${TASK_DIR}")"
    if [[ "${TASK_NAME}" =~ ^_ ]]; then
      continue
    fi

    CONFIG_FILE="${TASK_DIR}/task.conf"
    if [[ ! -f "${CONFIG_FILE}" ]]; then
      continue
    fi
    ENABLED="true"
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"

    if [[ "${ENABLED}" == "true" ]]; then
      systemctl --user enable --now "agy-task-${TASK_NAME}.timer" 2>/dev/null || true
      echo "  [ENABLED] agy-task-${TASK_NAME}.timer を有効化しました。"
    else
      systemctl --user disable --now "agy-task-${TASK_NAME}.timer" 2>/dev/null || true
      echo "  [DISABLED] agy-task-${TASK_NAME}.timer を無効化しました。"
    fi
  done
fi

# linger の有効化 (SSH 切断後もタイマーを生存させる)
if command -v loginctl >/dev/null 2>&1; then
  echo ""
  echo "[INFO] SSH ログアウト後も常駐実行するため linger を確認・有効化します..."
  loginctl enable-linger "${USER}" 2>/dev/null || echo "  [INFO] linger 設定は通常の SSH ログイン端末で 'loginctl enable-linger $USER' を実行してください。"
fi

echo ""
echo "=========================================================="
echo " [SUCCESS] 合計 ${INSTALLED_COUNT} 件のタスクユニットを配置・更新しました！"
echo "=========================================================="
echo ""
echo "■ 登録中タスクの一覧確認:"
echo "  make list"
echo ""
echo "■ 特定タスクの手動即時テスト実行:"
echo "  make run TASK=<タスク名>"
echo ""
echo "■ ログの確認:"
echo "  make log TASK=<タスク名>"
echo ""
