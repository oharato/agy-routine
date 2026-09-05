#!/usr/bin/env node
import { readFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = resolve(__dirname, '..');

function loadEnv(): void {
  const envPath = resolve(PROJECT_ROOT, '.env');
  if (!existsSync(envPath)) return;

  const content = readFileSync(envPath, 'utf-8');
  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) continue;

    const key = trimmed.slice(0, eqIdx).trim();
    let val = trimmed.slice(eqIdx + 1).trim();

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

// 見出し内のリンク構文（### 1. [タイトル](URL)）を Slack で確実にリンク化されるよう正規化
function normalizeMarkdownForSlack(text: string): string {
  // ### 1. [タイトル](URL) を ### 1. タイトル\n🔗 参照元: [記事リンク](URL) に変換
  return text.replace(
    /^(#{1,4}\s*(?:[0-9]+\.)?)\s*\[([^\]]+)\]\((https?:\/\/[^\s\)]+)\)/gm,
    '$1 $2\n🔗 参照元: [$2]($3)'
  );
}

function splitTextIntoMarkdownBlocks(text: string, maxLen = 10000): string[] {
  if (text.length <= maxLen) {
    return [text];
  }

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

  const filePathArg = process.argv[2];
  let rawText = '';

  if (filePathArg) {
    const targetFile = resolve(process.cwd(), filePathArg);
    if (!existsSync(targetFile)) {
      console.error(`[ERROR] 指定されたファイルが存在しません: ${targetFile}`);
      process.exit(1);
    }
    rawText = readFileSync(targetFile, 'utf-8');
  } else {
    rawText = readFileSync(0, 'utf-8');
  }

  if (!rawText.trim()) {
    console.warn('[WARN] 送信するメッセージ本文が空です。送信をスキップします。');
    process.exit(0);
  }

  // Slack 向けにリンクを安全に正規化
  const markdownText = normalizeMarkdownForSlack(rawText);

  console.log(`[INFO] Slack チャンネル (${channel}) へ送信中...`);

  const textChunks = splitTextIntoMarkdownBlocks(markdownText);
  const blocks = textChunks.map((chunk) => ({
    type: 'markdown',
    text: chunk,
  }));

  const payload = {
    channel,
    text: '🚀 Web開発・AI自動化トレンド要約レポートが届きました',
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
