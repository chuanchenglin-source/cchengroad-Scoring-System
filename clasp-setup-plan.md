# Clasp 環境設定作業計畫

## 背景說明

我是中途加入的協作開發者，非主導者。
主工程師已給予 Google Apps Script 專案的共同編輯權限。
目標是在本機建立開發環境，測試完成後透過 GitHub 提交給主工程師審核，**不直接修改正式版程式碼**。

---

## 前置確認

請先確認以下兩件事再開始：

1. 電腦是否已安裝 Node.js？
   - 終端機執行：`node -v`
   - 如果有版本號出現就是已安裝
   - 如果沒有，請先安裝 Node.js（https://nodejs.org）

2. 是否已有 GitHub 帳號？

---

## 作業目標

完成以下四件事：

1. 安裝 clasp 並登入 Google 帳號
2. 下載正式 Apps Script 專案到本機
3. 建立 GitHub Repo 並連結
4. 建立正確的資料夾結構

---

## 步驟一：安裝 clasp

```bash
npm install -g @google/clasp
```

安裝完成後確認：

```bash
clasp -v
```

出現版本號代表安裝成功。

---

## 步驟二：登入 Google 帳號

```bash
clasp login
```

執行後會自動開啟瀏覽器，用有權限的 Google 帳號登入並授權。

---

## 步驟三：建立專案資料夾

```bash
mkdir 專案名稱
cd 專案名稱
```

---

## 步驟四：下載 Apps Script 專案

需要主工程師提供 **Script ID**，取得方式：
- 打開 Apps Script 專案
- 點左側「專案設定」
- 複製「指令碼 ID」

取得 Script ID 後執行：

```bash
clasp clone <Script ID>
```

這會把雲端的程式碼下載到目前資料夾。

---

## 步驟五：初始化 Git 並連結 GitHub

```bash
git init
git add .
git commit -m "初始版本：從正式環境下載"
```

然後到 GitHub 建立新的 **Private Repo**，再執行：

```bash
git remote add origin <你的 GitHub Repo 網址>
git push -u origin main
```

---

## 步驟六：建立開發分支

**永遠不在 main 分支直接開發**，建立自己的開發分支：

```bash
git checkout -b develop
```

之後所有修改都在 develop 分支進行。

---

## 完成後的資料夾結構

```
專案資料夾/
├── CLAUDE.md              ← 專案說明（已準備好）
├── .clasp.json            ← clasp 設定檔（自動產生）
├── appsscript.json        ← Apps Script 設定檔（自動產生）
├── docs/
│   ├── 計分規則.md
│   └── 會議記錄/
└── src/                   ← Apps Script 程式碼
    └── Code.js（或其他 .js 檔）
```

---

## 日常開發流程

```
1. 確認在 develop 分支
   git checkout develop

2. 用 Claude Code 編輯程式碼

3. 本機測試（clasp run 或 clasp push 到測試環境）

4. 確認沒問題後提交
   git add .
   git commit -m "說明這次改了什麼"
   git push origin develop

5. 到 GitHub 發出 Pull Request
   通知主工程師審核

6. 主工程師審核後自行下載並上傳到正式 Apps Script
```

---

## 注意事項

- `.clasp.json` 裡有 Script ID，**不要公開**，建議加入 `.gitignore`
- 每次開始工作前先 `git pull` 確認拿到最新版本
- commit 訊息請用中文寫清楚改了什麼，方便主工程師審核

---

## 給 Claude Code 的指示

請協助我完成以上步驟，遇到問題請用非技術語言解釋，並提供我選項而不是直接幫我決定。
