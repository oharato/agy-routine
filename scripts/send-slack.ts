#!/usr/bin/env node
import { readFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// スクリプト自身のディレクトリとプロジェクトルート
const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = resolve(__dirname, '..');

// .env ファイルのパースと環境変数のロード
function loadEnv(): void {
  const envPath = resolve(PROJECT_ROOT, '.env');
  if (!existsSync(envPath)) {
    return;
  }

  const content = readFileSync(envPath, 'utf-8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) continue;

    const key = trimmed.slice(0, eqIdx).trim();
    let val = trimmed.slice(eqIdx + 1).trim();

    // クォートの除去
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }

    if (!process.env[key]) {
      process.env[key] = val;
    }
  }
}

// テキストを Slack の Block Kit 上限（3000文字）に配慮して分割する
function splitTextIntoBlocks(text: string, maxLen = 2900): string[] {
  const chunks: string[] = [];
  const lines = text.split('\n');
  let currentChunk = '';

  for (const line of lines) {
    if ((currentChunk + '\n' + line).length > maxLen) {
      if (currentChunk.trim()) {
        chunks.push(currentChunk.trim());
      }
      currentChunk = line;
    } else {
      currentChunk = currentChunk ? `${currentChunk}\n${line}` : line;
    }
  }

  if (currentChunk.trim()) {
    chunks.push(currentChunk.trim());
  }

  return chunks.length > 0 ? chunks : [text];
}

async function main(): Promise<void> {
  loadEnv();

  const token = process.env.SLACK_BOT_TOKEN;
  const channel = process.env.SLACK_CHANNEL;

  if (!token) {
    console.error('[ERROR] .env に SLACK_BOT_TOKEN が設定されていません。');
    process.exit(1);
  }

  if (!channel) {
    console.error('[ERROR] .env に SLACK_CHANNEL が設定されていません。');
    process.exit(1);
  }

  // 送信対象ファイルの取得（引数またはデフォルトレポートパス）
  const filePathArg = process.argv[2];
  let markdownText = '';

  if (filePathArg) {
    const targetFile = resolve(process.cwd(), filePathArg);
    if (!existsSync(targetFile)) {
      console.error(`[ERROR] 指定されたファイルが存在しません: ${targetFile}`);
      process.exit(1);
    }
    markdownText = readFileSync(targetFile, 'utf-8');
  } else {
    // 引数がない場合は標準入力から読む
    markdownText = readFileSync(0, 'utf-8');
  }

  if (!markdownText.trim()) {
    console.warn('[WARN] 送信するメッセージ本文が空です。送信をスキップします。');
    process.exit(0);
  }

  console.log(`[INFO] Slack チャンネル (${channel}) へレポートを送信中...`);

  // Block Kit の section ブロック配列を生成 (type: "mrkdwn")
  const textChunks = splitTextIntoBlocks(markdownText);
  const blocks = textChunks.map((chunk) => ({
    type: 'section',
    text: {
      type: 'mrkdwn',
      text: chunk,
    },
  }));

  // Slack API chat.postMessage ペイロード
  const payload = {
    channel,
    text: '🚀 Web開発・AI自動化トレンド要約レポートが届きました',
    mrkdwn: true,
    blocks,
  };

  try {
    const res = await fetch('https://slack.com/api/chat.postMessage', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify(payload),
    });

    const data = (await res.json()) as { ok: boolean; error?: string };

    if (!data.ok) {
      console.error(`[ERROR] Slack API エラー: ${data.error || '不明なエラー'}`);
      process.exit(1);
    }

    console.log('[SUCCESS] Slack へのメッセージ送信が完了しました！');
  } catch (error) {
    console.error('[ERROR] Slack 送信中にネットワークエラーが発生しました:', error);
    process.exit(1);
  }
}

main();
