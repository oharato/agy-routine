# 🏨 シーガイア「九州ふっこう応援割」新着情報チェック (`seagaia-fukko-wari`)

フェニックス・シーガイア・リゾート公式のお知らせページを定期巡回し、「九州ふっこう応援割」および関連する観光支援キャンペーンの新着情報をチェックして Slack に通知するルーティンタスクです。

## 概要
- **対象URL**: `https://seagaia.co.jp/information/`
- **チェック内容**: 「九州ふっこう応援割」「ふっこう割」「復興」等に関する新着情報の有無
- **実行スケジュール**: 毎日 10:00 (`*-*-* 10:00:00`)
- **配信先**: Slack（`SLACK_CHANNEL`）
- **履歴管理**: `reports/YYYY-MM-DD.md` にアーカイブし、`reports/README.md` に自動インデックス

## 特徴
1. **認知負荷の低減**:
   - 長文を避け、すべて簡潔な箇条書きで構成。
2. **スクレイピング正常性の可視化**:
   - 新着情報がない日でも「新着発表なし」とともに直近のお知らせ最新3件を参考情報として添えることで、巡回が正常に動作していることを担保。
3. **Slack 表示最適化**:
   - 見出し内のリンクを避け、独立行のリンク記法を採用することで、Slack 側でのリンク崩れを防止。

## ファイル構成
- [`prompt.md`](file:///home/oharato/workspace/agy-routine/tasks/seagaia-fukko-wari/prompt.md): 巡回・抽出・レポート作成の指示書
- [`task.conf`](file:///home/oharato/workspace/agy-routine/tasks/seagaia-fukko-wari/task.conf): 実行スケジュール (`*-*-* 10:00:00`)、思考レベル (`low`) 等の設定
- [`post-run.sh`](file:///home/oharato/workspace/agy-routine/tasks/seagaia-fukko-wari/post-run.sh): レポートのアーカイブ保存、目次更新、Slack 通知を行う事後処理スクリプト
- `reports/`: 過去レポートの履歴アーカイブ（自動生成）

