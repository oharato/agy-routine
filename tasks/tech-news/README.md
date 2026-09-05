# AI開発自動化・効率化トレンド調査 (`tech-news`)

## 概要
AIを活用した開発フローの自動化・効率化（AIコーディングエージェント、開発パイプラインの自動化、CI/CD・Hook連携、ハーネス設計、コードレビュー自動化、テスト自動生成など）に関する国内外の重要トレンドや実践記事を自動調査・要約し、**Slack の指定チャンネルに最新の `type: "markdown"` ブロック形式で自動配信**するとともに、**日付別アーカイブとして履歴を自動蓄積**するタスクです。

## 実行スケジュール
- **頻度**: 毎日 09:00 (`*-*-* 09:00:00`)
- **思考レベル**: `medium`
- **タイムアウト**: 900秒（15分）

## 主な情報ソース
- **国内**: はてなブックマーク テクノロジー、Zenn、Qiita、各社テックブログ
- **海外**: Hacker News、GitHub Trending、DEV.to、daily.dev など

## レポート履歴管理 (自動アーカイブ)
毎回の実行結果は上書きされるだけでなく、[`reports/`](reports/) ディレクトリに日付別で自動保存されます：
- **`reports/YYYY-MM-DD.md`**: 各日の個別レポートファイル
- **`reports/latest.md`**: 常に最新のレポートへのシンボリックリンク
- **[`reports/README.md`](reports/README.md)**: 過去レポートの目次・注目トピック一覧（実行時に自動更新）
- **`report.md`**: 常に最新のレポート本体

## Slack 配信仕様 (最新 Block Kit `type: "markdown"`)
2025年に追加された Slack の **`markdown` ブロック**を採用しています：
- **標準 Markdown ネイティブ対応**: LLM が生成する見出し（`#`）、太字（`**bold**`）、テーブル（`| col1 | col2 |`）、リスト、コードブロック等を変換なしでそのまま美しくレンダリングします。
- **大容量対応**: 従来の `mrkdwn`（3,000文字）から、全ブロック合計最大 12,000 文字まで対応。

## 配信・出力フロー
1. エージェントが Web リサーチを実施し、国内5件・海外5件の構造化サマリーを作成。
2. 作成されたレポートを `tasks/tech-news/report.md` に保存。
3. 事後フック [`post-run.sh`](post-run.sh) が発火：
   - `reports/YYYY-MM-DD.md` へアーカイブ保存
   - 目次インデックス [`reports/README.md`](reports/README.md) を自動更新
   - 最新シンボリックリンク `reports/latest.md` を更新
   - [`scripts/send-slack.ts`](../../scripts/send-slack.ts) を呼び出し、`.env` の認証情報で Slack チャンネルへ配信。

## 必要な環境変数 (`.env`)
```env
SLACK_BOT_TOKEN="xoxb-your-bot-token"
SLACK_CHANNEL="C0123456789" # または #tech-news
```

## 手動テスト
```bash
# タスクのフル実行（調査からアーカイブ保存、Slack送信まで）
make run TASK=tech-news

# Slack 送信のみの疎通テスト (type: "markdown" で送信されます)
make test-slack
```
