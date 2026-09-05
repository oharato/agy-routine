# トラブルシューティング & Tips (マルチタスク版)

定期実行（マルチタスク無人運用）において発生しやすい問題とその解決策です。

---

## 1. よくある問題と対処法

### Q1: 新しいタスクを追加したのにタイマーが動かない
- **原因**:
  タスクフォルダを作成した後に、タイマーのインストールコマンドを実行していない可能性があります。
- **対処法**:
  タスクフォルダ作成後、必ず以下を実行してください:
  ```bash
  ./scripts/install-tasks.sh
  ```
  また、`tasks/<タスク名>/task.conf` の `ENABLED="true"` になっているかも確認してください。

---

### Q2: 特定のタスクだけ失敗・エラーになる
- **対処法**:
  失敗したタスク専用のログを確認してください:
  ```bash
  # ファイルログを確認
  cat logs/<タスク名>/routine-$(date +'%Y%m%d').log

  # 直近の journald エラーログを確認
  journalctl --user -u agy-task@<タスク名>.service -p err -e
  ```
  また、手動でそのタスクを実行してエラー内容を特定します:
  ```bash
  ./scripts/run-task.sh <タスク名>
  ```

---

### Q3: SSH ログアウトするとすべての定期実行が止まる
- **原因**:
  systemd のユーザーセッションデーモンがログアウト時に終了しています。
- **対処法**:
  `loginctl enable-linger` を有効化してください:
  ```bash
  loginctl enable-linger $USER
  ```
  確認コマンド:
  ```bash
  loginctl show-user $USER --property=Linger
  # Linger=yes と表示されれば正常です
  ```

---

### Q4: `agy: command not found` で失敗する
- **原因**:
  非対話セッションで `PATH` が通っていません。
- **対処法**:
  `scripts/run-task.sh` 内で以下のように PATH を補完しています:
  ```bash
  export PATH="${HOME}/.local/share/mise/shims:${HOME}/.local/bin:${PATH}"
  ```
  別の場所に `agy` を配置している場合は、そのディレクトリを PATH に追加してください。

---

### Q5: 処理がタイムアウトして強制終了される
- **原因**:
  タスクの処理時間が `task.conf` の `TIMEOUT` またはサービスの `TimeoutStartSec` を超過したためです。
- **対処法**:
  1. `tasks/<タスク名>/task.conf` の `TIMEOUT` を延長する（例: `TIMEOUT=1800`）。
  2. `systemd/agy-task@.service` の `TimeoutStartSec=1800` を確認し、`./scripts/install-tasks.sh` で再反映する。
  3. 指示書（`prompt.md`）のスコープを小さく分割するか、`EFFORT="low"` にして高速化する。

---

## 2. 便利な運用 Tips

### 特定タスクだけ無効化したい
タスクフォルダを削除しなくても、`tasks/<タスク名>/task.conf` 内の `ENABLED="false"` に変更して `./scripts/install-tasks.sh` を実行するだけで、そのタスクのタイマーのみが無効化されます。

### タスクごとに通知（Slack / Discord 等）を飛ばしたい
タスクフォルダ内に `post-run.sh` を配置し、実行権限（`chmod +x`）を与えます:
```bash
#!/usr/bin/env bash
if [[ "${TASK_EXIT_CODE}" -ne 0 ]]; then
  curl -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"[ALERT] タスク $(basename $(pwd)) が失敗しました。\"}" \
    "${SLACK_WEBHOOK_URL}"
fi
```
