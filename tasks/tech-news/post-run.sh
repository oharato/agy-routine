#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPORTS_DIR="${SCRIPT_DIR}/reports"
mkdir -p "${REPORTS_DIR}"

echo "[post-run] tech-news の事後処理（履歴アーカイブ & Slack送信）を開始します..."

# タスクが失敗した場合は送信しない
if [[ "${TASK_EXIT_CODE:-0}" -ne 0 ]]; then
  echo "[post-run] [WARN] タスクがエラー終了したため、Slack への成果物送信をスキップします (ExitCode: ${TASK_EXIT_CODE:-0})。"
  exit 0
fi

DATE_STR="$(date +'%Y-%m-%d')"
TARGET_ARCHIVE_FILE="${REPORTS_DIR}/${DATE_STR}.md"
LATEST_REPORT_FILE="${SCRIPT_DIR}/report.md"

# report.md が生成されていればアーカイブ
if [[ -f "${LATEST_REPORT_FILE}" ]]; then
  cp "${LATEST_REPORT_FILE}" "${TARGET_ARCHIVE_FILE}"
  echo "[post-run] レポートを日付別アーカイブに保存しました: ${TARGET_ARCHIVE_FILE}"
elif [[ -f "${TARGET_ARCHIVE_FILE}" ]]; then
  echo "[post-run] アーカイブファイルが既に存在します: ${TARGET_ARCHIVE_FILE}"
else
  # ログファイルからのフォールバック
  LOG_FILE="${PROJECT_ROOT}/logs/tech-news/routine-$(date +'%Y%m%d').log"
  if [[ -f "${LOG_FILE}" ]]; then
    echo "[post-run] report.md が無いため、ログファイルからコピーします: ${LOG_FILE}"
    cp "${LOG_FILE}" "${TARGET_ARCHIVE_FILE}"
  else
    echo "[post-run] [ERROR] 送信対象のレポートファイルが見つかりません。"
    exit 1
  fi
fi

# 過去レポートの目次 (reports/README.md) を自動生成・更新
INDEX_FILE="${REPORTS_DIR}/README.md"
cat << 'INDEX_HEADER' > "${INDEX_FILE}"
# 📰 AI開発自動化トレンド レポート履歴アーカイブ

毎日の定期実行で収集・要約されたトレンドレポートの履歴一覧です（新しい順）。

| 日付 | レポートリンク | 注目トピック例 |
| :--- | :--- | :--- |
INDEX_HEADER

# reports/ 内の日付 Markdown ファイルを降順で走査
for REPORT_PATH in $(ls -r "${REPORTS_DIR}"/*.md 2>/dev/null); do
  BASENAME="$(basename "${REPORT_PATH}")"
  if [[ "${BASENAME}" == "README.md" || "${BASENAME}" == "latest.md" ]]; then
    continue
  fi
  DATE_NAME="${BASENAME%.md}"

  # レポート内の最初のトピックタイトルを抽出
  FIRST_TOPIC=$(grep -m 1 -E '^### [0-9]+\. \[' "${REPORT_PATH}" | sed -E 's/^### [0-9]+\. \[([^]]+)\].*/\1/' || true)
  if [[ -z "${FIRST_TOPIC}" ]]; then
    FIRST_TOPIC="日次トレンドレポート"
  fi

  echo "| **${DATE_NAME}** | [${DATE_NAME} レポート](${BASENAME}) | ${FIRST_TOPIC} 等 |" >> "${INDEX_FILE}"
done

echo "[post-run] 目次インデックス (reports/README.md) を自動更新しました。"

# 最新レポートへのシンボリックリンク（latest.md）を更新
ln -sf "${DATE_STR}.md" "${REPORTS_DIR}/latest.md"

# Slack への送信 (最新アーカイブファイルを送信)
cd "${PROJECT_ROOT}"
node --experimental-strip-types scripts/send-slack.ts "${TARGET_ARCHIVE_FILE}"

echo "[post-run] Slack 送信および履歴管理が正常に完了しました。"
