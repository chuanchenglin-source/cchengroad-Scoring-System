#!/usr/bin/env node
/**
 * 跨平台環境設定腳本
 *
 * 用途：在新機器（例如 Mac 或新 Windows 電腦）首次 clone 本專案後，
 *       自動建立 .clasp.dev.json / .clasp.prod.json / .clasp.json 三個檔案。
 *       這三個檔案因為含有敏感 Script ID 所以被 .gitignore 排除。
 *
 * 使用方式：
 *   node scripts/setup-env.mjs
 *
 * 執行後的狀態：
 *   - .clasp.dev.json  → 指向測試 Apps Script
 *   - .clasp.prod.json → 指向正式 Apps Script（備份用，無對應 npm 指令）
 *   - .clasp.json      → 預設指向【測試】DEV 環境
 *
 * 接下來還需要手動執行：
 *   1. npx clasp login   （瀏覽器 Google OAuth 授權，首次使用必做）
 *   2. npm run push:dev  （驗證推送到測試環境）
 */

import { writeFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(__dirname, '..');

// Script IDs（與 CLAUDE.md「測試環境資源」章節一致）
const TEST_SCRIPT_ID = '1xR7aWeaeAzUjzoQMO1m6cWkkJrCW85-2IlU0_NHU-IPReOX4mtg0ttxY';
const PROD_SCRIPT_ID = '19ZCMtO64t7drgu-MVY-kbCJpOcW8kvpjDjsu0mfBFszyjRmP6ghqc8NV';

const devConfig  = { scriptId: TEST_SCRIPT_ID, rootDir: '.' };
const prodConfig = { scriptId: PROD_SCRIPT_ID, rootDir: '.' };

// 檔案路徑
const devPath   = resolve(projectRoot, '.clasp.dev.json');
const prodPath  = resolve(projectRoot, '.clasp.prod.json');
const activePath = resolve(projectRoot, '.clasp.json');

// 安全檢查：如果檔案已存在，先警告
const existing = [devPath, prodPath, activePath].filter(p => existsSync(p));
if (existing.length > 0) {
  console.log('⚠️  偵測到以下檔案已存在，將被覆寫：');
  existing.forEach(p => console.log('   -', p.split(/[\\/]/).pop()));
  console.log('');
}

// 寫入三個檔案
writeFileSync(devPath,    JSON.stringify(devConfig)  + '\n');
writeFileSync(prodPath,   JSON.stringify(prodConfig) + '\n');
writeFileSync(activePath, JSON.stringify(devConfig)  + '\n'); // 預設指向 dev

console.log('✓ 建立 .clasp.dev.json   →', TEST_SCRIPT_ID);
console.log('✓ 建立 .clasp.prod.json  →', PROD_SCRIPT_ID);
console.log('✓ 設定 .clasp.json       → 預設【測試】DEV 環境');
console.log('');
console.log('下一步：');
console.log('  1. npx clasp login     # 瀏覽器授權 Google 帳號（只需做一次）');
console.log('  2. npm run env:status  # 確認當前環境');
console.log('  3. npm run push:dev    # 測試推送到測試環境');
