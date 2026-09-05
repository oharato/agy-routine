# AI開発自動化・効率化トレンド調査 (`tech-news`)

## 概要
AIを活用した開発フローの自動化・効率化（AIコーディングエージェント、開発パイプラインの自動化、CI/CD・Hook連携、ハーネス設計、コードレビュー自動化、テスト自動生成など）に関する国内外の重要トレンドや実践記事を自動調査・要約し、**Slack の指定チャンネルに Markdown 形式で自動配信**するタスクです。

## 実行スケジュール
- **頻度**: 毎日 09:00 (`*-*-* 09:00:00`)
- **思考レベル**: `medium`
- **タイムアウト**: 900秒（15分）

## 主な情報ソース
- **国内**: はてなブックマーク テクノロジー、Zenn、Qiita、各社テックブログ
- **海外**: Hacker News、GitHub Trending、DEV.to、daily.dev など

## 配信・出力フロー
1. エージェントが Web リサーチを実施し、国内5件・海外5件の構造化サマリーを作成。
2. 作成されたレポートを `tasks/tech-news/report.md` に保存。
3. 事後フック [`post-run.sh`](post-run.sh) が発火し、[`scripts/send-slack.ts`](../../scripts/send-slack.ts) を呼び出し。
4. `.env` の `SLACK_BOT_TOKEN` と `SLACK_CHANNEL` を使用して Slack API（`type: mrkdwn`）で送信。

## 必要な環境変数 (`.env`)
```env
SLACK_BOT_TOKEN="xoxb-your-bot-token"
SLACK_CHANNEL="C0123456789" # または #tech-news
```

## 手動テスト
```bash
# タスクのフル実行（調査からSlack送信まで）
make run TASK=tech-news

# Slack 送信のみの疎通テスト
make test-slack
```
