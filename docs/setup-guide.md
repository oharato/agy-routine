# 詳細セットアップガイド (Makefile 版)

本ガイドでは、Windows から Linux マシンに SSH 接続し、複数の定期実行タスクを独立稼働させるための環境構築・運用手順を解説します。

---

## 1. 前提条件

- **Windows クライアント**:
  - OpenSSH クライアント（PowerShell または Windows Terminal）
  - （推奨）VS Code または Antigravity IDE（Remote - SSH 拡張）
- **Linux サーバー / ホスト**:
  - Ubuntu / Debian / RHEL 等の Linux OS
  - SSH サーバー (`sshd`) が稼働していること
  - `make`, `curl`, `git`, `bash`

---

## 2. Linux 側での初期準備

### (1) SSH 接続
Windows の PowerShell から Linux へ接続します。
```powershell
ssh <ユーザー名>@<Linuxホスト名またはIP>
cd ~/workspace/agy-routine
```

### (2) agy CLI の動作確認
```bash
which agy
agy --version
```

### (3) 初回認証（ヘッドレス SSH 認証）
無人実行を行うためには、エージェントが正常に認証されている必要があります。
```bash
agy -p "ping"
```
- ブラウザが開けない環境の場合、端末上に認証用 URL が表示されます。
- その URL を **Windows 側のブラウザ** で開き、Google アカウント等でログインを完了して承認コードをターミナルに貼り付けます。
- または、`.env` ファイルを作成して API キーを設定します:
  ```env
  ANTIGRAVITY_API_KEY="your-api-key-here"
  ```

---

## 3. タスクの確認とセットアップ

### (1) 定義済みタスクの確認
現在登録されているタスクやスケジュールを一覧表示します。
```bash
make list
```

### (2) 特定タスクの手動テスト実行
タイマー登録前に、単体でタスクが正しく動作するかテストします。
```bash
make run TASK=daily-git-digest
```
※ ログは `logs/daily-git-digest/routine-YYYYMMDD.log` に出力されます。

### (3) 全タスクのタイマー一括登録・有効化
```bash
make install
```
このコマンドにより、自動的に以下が行われます：
1. 共通テンプレートサービス `agy-task@.service` を配置
2. `tasks/` 以下の各タスク用タイマー（`agy-task-<task-name>.timer`）を自動生成して配置
3. `systemctl --user daemon-reload`
4. 有効化（`enable --now`）
5. `loginctl enable-linger $USER` による SSH 切断後の常駐化

---

## 4. 運用の基本コマンド (Makefile リファレンス)

```bash
# 全タスクの一覧と次回発火予定の確認
make list

# systemd タイマーの稼働状態を詳細確認
make status

# 特定タスクのファイルログを確認
make log TASK=<タスク名>

# journald リアルタイムログを追跡
make journal TASK=<タスク名>

# 特定タスクのタイマーを一時停止
make stop TASK=<タスク名>

# 特定タスクのタイマーを再開
make start TASK=<タスク名>

# 新規タスクの作成
make new TASK=<タスク名>
```
