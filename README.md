# agy-routine: Antigravity CLI 複数定期実行タスク基盤

Windows から Linux マシンに SSH 接続してセットアップを行い、**Linux 側で複数の独立した Antigravity CLI (`agy`) 定期実行タスクを完全自動・無人で稼働・管理させるためのフレームワーク**です。

`Makefile` による直感的なコマンド体系を備えており、新規タスクの作成からテスト実行、タイマー登録、ログ確認までシンプルに操作できます。

---

## 1. 特徴

- **Makefile によるワンライナー操作**: `make new`, `make list`, `make run`, `make install` などの直感的な操作。
- **マルチタスク完全対応**: `tasks/` ディレクトリ配下にタスクごとのフォルダを作成するだけで、複数の定期実行タスクを独立管理可能。
- **指示書の Markdown 化**: タスクごとの指示内容を `prompt.md` に Markdown 形式で詳細に記述可能。
- **個別スケジュール管理**: タスクごとに異なる実行スケジュール（毎日、平日朝、毎週末など）を `task.conf` で個別に設定。
- **ログの完全分離**: タスクごとに `logs/<タスク名>/` へ実行ログを分離保存。
- **完全無人化 & セッション永続化**: `systemd.timer` と `loginctl enable-linger` により、Windows PC の電源を切っても Linux 単体で自律稼働。
- **事前/事後フック対応**: タスク実行前後のシェルスクリプト（通知や Git push など）を配置可能。

---

## 2. ディレクトリ構造

```text
agy-routine/
├── Makefile                    # ★操作用コマンド一式 (make new, list, run, install等)
├── .mise.toml                  # ランタイム・ツールバージョン固定設定
├── README.md                   # 全体概要・クイックスタート (本ファイル)
├── docs/                       # 詳細ドキュメント群
│   ├── task-guide.md           # 新規タスクの作成・追加ガイド
│   ├── architecture.md         # 仕組み・マルチタスク設計詳細
│   ├── setup-guide.md          # 環境構築・インストール手順
│   └── troubleshooting.md      # トラブルシューティング & Tips
├── tasks/                      # タスク定義ディレクトリ
│   ├── _template/              # 新規タスク用ひな形 (make new のコピー元)
│   │   ├── prompt.md           # エージェントへの指示書 (Markdown)
│   │   ├── task.conf           # スケジュール・設定定義
│   │   └── README.md           # タスク仕様
│   ├── tech-news/              # 実装タスク: 毎朝9時 AI開発自動化トレンド収集 & Slack配信
│   │   ├── prompt.md
│   │   ├── task.conf
│   │   ├── post-run.sh
│   │   └── reports/
│   └── seagaia-fukko-wari/     # 実装タスク: 毎日10時 シーガイア「九州ふっこう応援割」チェック & Slack配信
│       ├── prompt.md
│       ├── task.conf
│       ├── post-run.sh
│       └── reports/
├── systemd/                    # systemd ユニット定義
│   └── agy-task@.service       # 共通テンプレートサービス (agy-task@<タスク名>.service)
├── scripts/                    # 実行・管理スクリプト
│   ├── install-tasks.sh        # 全タスクのタイマー一括登録・更新
│   ├── list-tasks.sh           # 定義済みタスクと稼働タイマーの一覧表示
│   └── run-task.sh             # 特定タスクの手動/単体実行ランナー
└── logs/                       # タスク別ログディレクトリ (logs/<タスク名>/)
```

---

## 3. クイックスタート (Makefile ベース)

### ステップ 1: Windows から Linux へ SSH 接続
```bash
ssh <ユーザー名>@<Linuxマシンのホスト名またはIP>
cd ~/workspace/agy-routine
```

### ステップ 2: 登録タスク一覧の確認
```bash
make list
```

### ステップ 3: 手動テスト実行
```bash
# daily-git-digest タスクを手動実行してログ出力を確認
make run TASK=daily-git-digest
```
※ ログは `logs/daily-git-digest/routine-YYYYMMDD.log` に自動保存されます。

### ステップ 4: 全タスクのタイマー登録・有効化
```bash
make install
```
※ 全タスクのタイマーが生成・有効化され、SSH ログアウト後も動き続けるよう `linger` が設定されます。

---

## 4. 新しいタスクを追加する流れ

```bash
# 1. テンプレートから新規タスクを作成
make new TASK=my-audit-task

# 2. 生成された指示書 (prompt.md) と設定 (task.conf) を編集
nano tasks/my-audit-task/prompt.md
nano tasks/my-audit-task/task.conf

# 3. 反映コマンドを実行 (systemd タイマーが自動生成・有効化されます)
make install

# 4. 手動テスト実行
make run TASK=my-audit-task
```
※ 詳しい書き方は [新規タスク作成・追加ガイド (docs/task-guide.md)](docs/task-guide.md) をご覧ください。

---

## 5. 操作コマンド一覧 (Makefile リファレンス)

| コマンド | 説明 | 例 |
| :--- | :--- | :--- |
| `make help` | コマンド一覧と使い方ヘルプを表示 | `make help` |
| `make new TASK=<名>` | テンプレートから新規タスクフォルダを作成 | `make new TASK=code-review` |
| `make list` | 登録タスク一覧とスケジュールを表示 | `make list` |
| `make install` | `tasks/` 配下の全タスクのタイマーを一括登録・有効化 | `make install` |
| `make run TASK=<名>` | 指定タスクを手動テスト実行 | `make run TASK=daily-git-digest` |
| `make status` | systemd タイマーの稼働状況を確認 | `make status` |
| `make log TASK=<名>` | 指定タスクの本日ログファイルを表示 | `make log TASK=daily-git-digest` |
| `make journal TASK=<名>` | 指定タスクのリアルタイムログを追跡 | `make journal TASK=daily-git-digest` |
| `make stop TASK=<名>` | 指定タスクのタイマーを一時停止 | `make stop TASK=daily-git-digest` |
| `make start TASK=<名>` | 指定タスクのタイマーを再開 | `make start TASK=daily-git-digest` |

---

## 6. ドキュメント一覧
- [新規タスク作成・追加ガイド (docs/task-guide.md)](docs/task-guide.md)
- [アーキテクチャ詳細・仕組み (docs/architecture.md)](docs/architecture.md)
- [詳細セットアップガイド (docs/setup-guide.md)](docs/setup-guide.md)
- [トラブルシューティング (docs/troubleshooting.md)](docs/troubleshooting.md)
