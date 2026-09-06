#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPORTS_DIR="${SCRIPT_DIR}/reports"
mkdir -p "${REPORTS_DIR}"

echo "[post-run] seagaia-fukko-wari の事後処理（履歴アーカイブ & Slack送信）を開始します..."

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
  # ログファイルからのフォールバック（Markdown部分の抽出を試みる）
  LOG_FILE="${PROJECT_ROOT}/logs/seagaia-fukko-wari/routine-$(date +'%Y%m%d').log"
  if [[ -f "${LOG_FILE}" ]]; then
    echo "[post-run] report.md が無いため、ログファイルから Markdown 抽出を試みます: ${LOG_FILE}"
    node -e '
      const fs = require("fs");
      const content = fs.readFileSync(process.argv[1], "utf-8");
      const mdMatch = content.match(/```markdown\r?\n([\s\S]*?)\r?\n```/);
      if (mdMatch) {
        fs.writeFileSync(process.argv[2], mdMatch[1].trim() + "\n");
      } else {
        const headerIdx = content.indexOf("# ");
        if (headerIdx !== -1) {
          const cutIdx = content.indexOf("[INFO] Executing post-run hook", headerIdx);
          const reportText = cutIdx !== -1 ? content.slice(headerIdx, cutIdx) : content.slice(headerIdx);
          fs.writeFileSync(process.argv[2], reportText.trim() + "\n");
        } else {
          fs.writeFileSync(process.argv[2], content);
        }
      }
    ' "${LOG_FILE}" "${TARGET_ARCHIVE_FILE}"
    cp "${TARGET_ARCHIVE_FILE}" "${LATEST_REPORT_FILE}"
    echo "[post-run] ログファイルからレポートを抽出し保存しました: ${TARGET_ARCHIVE_FILE}"
  else
    echo "[post-run] [ERROR] 送信対象のレポートファイルが見つかりません。"
    exit 1
  fi
fi

# 過去レポートの目次 (reports/README.md) を自動生成・更新
INDEX_FILE="${REPORTS_DIR}/README.md"
cat << 'INDEX_HEADER' > "${INDEX_FILE}"
# 📢 【シーガイア】九州ふっこう応援割 チェック履歴アーカイブ

毎日の定期実行で確認されたフェニックス・シーガイア・リゾートの「九州ふっこう応援割」チェック履歴一覧です（新しい順）。

| 日付 | レポートリンク | ステータス・概要 |
| :--- | :--- | :--- |
INDEX_HEADER

# reports/ 内の日付 Markdown ファイルを降順で走査
for REPORT_PATH in $(ls -r "${REPORTS_DIR}"/*.md 2>/dev/null); do
  BASENAME="$(basename "${REPORT_PATH}")"
  if [[ "${BASENAME}" == "README.md" || "${BASENAME}" == "latest.md" ]]; then
    continue
  fi
  DATE_NAME="${BASENAME%.md}"

  # レポート内の状況・トピックを抽出
  STATUS_SUMMARY="新着なし (巡回完了)"
  if grep -q -E "### 1\." "${REPORT_PATH}"; then
    FIRST_TITLE=$(grep -m 1 -E '^### [0-9]+\. ' "${REPORT_PATH}" | sed -E 's/^### [0-9]+\. //; s/\[//g; s/\]//g' || true)
    STATUS_SUMMARY="【新着あり】${FIRST_TITLE}"
  fi

  echo "| **${DATE_NAME}** | [${DATE_NAME} レポート](${BASENAME}) | ${STATUS_SUMMARY} |" >> "${INDEX_FILE}"
done

echo "[post-run] 目次インデックス (reports/README.md) を自動更新しました。"

# 最新レポートへのシンボリックリンク（latest.md）を更新
ln -sf "${DATE_STR}.md" "${REPORTS_DIR}/latest.md"

# Slack への送信 (最新アーカイブファイルを送信)
cd "${PROJECT_ROOT}"
node --experimental-strip-types scripts/send-slack.ts "${TARGET_ARCHIVE_FILE}"

echo "[post-run] Slack 送信および履歴管理が正常に完了しました。"
