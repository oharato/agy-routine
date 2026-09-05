# agy-routine 管理用 Makefile
SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

.PHONY: help new list install run status log journal stop start test-slack typecheck

help: ## 利用可能なコマンド一覧を表示します
	@echo "=========================================================================="
	@echo " agy-routine: Antigravity CLI 定期実行タスク管理コマンド"
	@echo "=========================================================================="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "■ 使用例:"
	@echo "  make new TASK=my-check        # 新規タスク 'my-check' をテンプレートから作成"
	@echo "  make list                     # 登録タスク一覧とスケジュールを表示"
	@echo "  make run TASK=tech-news       # 指定タスクを手動テスト実行 (Slack送信含む)"
	@echo "  make test-slack               # Slack 送信設定 (.env) の疎通テスト"
	@echo "  make install                  # 全タスクのタイマーを一括生成・有効化"
	@echo "  make status                   # systemd タイマーの稼働状況を確認"
	@echo "  make log TASK=tech-news       # 今日の実行ログファイルを表示"
	@echo "  make journal TASK=tech-news   # systemd のリアルタイムログを追跡"
	@echo "=========================================================================="

new: ## 新規タスクを作成します (例: make new TASK=my-task)
	@if [ -z "$(TASK)" ]; then \
		echo -e "[\033[31mERROR\033[0m] TASK 名を指定してください。 (例: make new TASK=my-audit-task)"; \
		exit 1; \
	fi
	@if [ -d "tasks/$(TASK)" ]; then \
		echo -e "[\033[31mERROR\033[0m] タスク 'tasks/$(TASK)' は既に存在します。"; \
		exit 1; \
	fi
	@mkdir -p tasks/$(TASK)
	@cp -r tasks/_template/* tasks/$(TASK)/
	@echo "=========================================================="
	@echo -e " [\033[32mSUCCESS\033[0m] 新規タスク 'tasks/$(TASK)' を作成しました！"
	@echo "=========================================================="
	@echo "1. 指示書を編集:  nano tasks/$(TASK)/prompt.md"
	@echo "2. 設定を編集:    nano tasks/$(TASK)/task.conf"
	@echo "3. 反映コマンド:  make install"
	@echo "4. 手動テスト:    make run TASK=$(TASK)"

list: ## 定義済みタスクと稼働タイマーの一覧を表示します
	@./scripts/list-tasks.sh

install: ## tasks/ 配下の全タスクのタイマーを一括生成・有効化します
	@./scripts/install-tasks.sh

run: ## 指定タスクを手動テスト実行します (例: make run TASK=tech-news)
	@if [ -z "$(TASK)" ]; then \
		echo -e "[\033[31mERROR\033[0m] TASK 名を指定してください。 (例: make run TASK=tech-news)"; \
		exit 1; \
	fi
	@./scripts/run-task.sh $(TASK)

status: ## systemd タイマーのアクティブ状況を確認します
	@systemctl --user list-timers 'agy-task-*'

log: ## 指定タスクの本日ログファイルを表示します (例: make log TASK=tech-news)
	@if [ -z "$(TASK)" ]; then \
		echo -e "[\033[31mERROR\033[0m] TASK 名を指定してください。 (例: make log TASK=tech-news)"; \
		exit 1; \
	fi
	@LOG_FILE="logs/$(TASK)/routine-$$(date +'%Y%m%d').log"; \
	if [ -f "$$LOG_FILE" ]; then \
		cat "$$LOG_FILE"; \
	else \
		echo -e "[\033[33mWARN\033[0m] 本日のログファイルが見つかりません: $$LOG_FILE"; \
	fi

journal: ## 指定タスクの systemd リアルタイムログを追跡します (例: make journal TASK=tech-news)
	@if [ -z "$(TASK)" ]; then \
		echo -e "[\033[31mERROR\033[0m] TASK 名を指定してください。 (例: make journal TASK=tech-news)"; \
		exit 1; \
	fi
	@journalctl --user -u agy-task@$(TASK).service -f

stop: ## 指定タスクのタイマーを一時停止します (例: make stop TASK=tech-news)
	@if [ -z "$(TASK)" ]; then \
		echo -e "[\033[31mERROR\033[0m] TASK 名を指定してください。"; \
		exit 1; \
	fi
	@systemctl --user stop agy-task-$(TASK).timer
	@echo -e "[\033[32mOK\033[0m] agy-task-$(TASK).timer を停止しました。"

start: ## 指定タスクのタイマーを再開します (例: make start TASK=tech-news)
	@if [ -z "$(TASK)" ]; then \
		echo -e "[\033[31mERROR\033[0m] TASK 名を指定してください。"; \
		exit 1; \
	fi
	@systemctl --user start agy-task-$(TASK).timer
	@echo -e "[\033[32mOK\033[0m] agy-task-$(TASK).timer を再開しました。"

test-slack: ## Slack 送信 (.env) の疎通テストを実行します
	@echo "Slack 疎通テスト中..."
	@echo -e "🚀 *[agy-routine]* Slack 疎通テストメッセージです。\n正常に受信できています！" | node --experimental-strip-types scripts/send-slack.ts

typecheck: ## TypeScript の型チェックを実行します
	@pnpm typecheck
