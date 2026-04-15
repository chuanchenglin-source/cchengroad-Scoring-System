// 排程設定

function rebuildSummaryReport() {
  const ss = SpreadsheetApp.openById(SS_ID_SCORE);
  const allSheets = ss.getSheets();
  const summarySheetName = "每日戰隊總分彙總";
  const userDetailSheetName = "每日個人分數結算";
  
  const masterData = {};

  allSheets.forEach(sheet => {
    const sheetName = sheet.getName();
    // 過濾非數據分頁
    if (["人員總表", summarySheetName, userDetailSheetName, "Config"].includes(sheetName)) return;

    const data = sheet.getDataRange().getValues();
    if (data.length <= 1) return;

    console.log(`正在讀取: ${sheetName}，共 ${data.length - 1} 筆原始資料`);

    for (let i = 1; i < data.length; i++) {
      const row = data[i];
      const timestamp = new Date(row[0]); // 時間戳記 (A)
      const userId    = row[1];           // 使用者ID (B)
      const teamName  = sheetName;        // 戰隊名
      const userName  = row[2];           // 小隊姓名 (C)
      const dateVal   = row[4];           // 登記日期 (D)
      
      // 檢查必要欄位，無效則跳過
      if (!userId || !dateVal || isNaN(timestamp.getTime())) continue;

      const regDateStr = (dateVal instanceof Date) 
        ? Utilities.formatDate(dateVal, "GMT+8", "yyyy/MM/dd")
        : dateVal.toString().trim();
      if (!masterData[regDateStr]) masterData[regDateStr] = {};
      if (!masterData[regDateStr][teamName]) masterData[regDateStr][teamName] = {};

      const existing = masterData[regDateStr][teamName][userId];

      // 只保留該使用者當天最後一筆提交的資料
      if (!existing || timestamp > existing.ts) {
        console.log(row.slice(6, 31));
        masterData[regDateStr][teamName][userId] = {
          ts: timestamp,
          name: userName,
          // 根據你提供的來源欄位：
          // row[4]是總分, row[5]是BOX1...以此類推
          totalScore: Number(row[5]) || 0, 
          boxes: row.slice(6, 31), // 抓取 BOX1 (row[5]) 到 BOX13 (row[17])
          remark: row[32]          // 備註 (row[18])
        };
      }
    }
  });

  const sortedDates = Object.keys(masterData).sort().reverse();
  
  // 設定明細表標題 (對應前端 AJAX 需要的 33 欄結構)
  const userDetailHeaders = [
    "登記日期", "戰隊", "ID", "姓名", "採計分數", "原始填寫時間",
    "BOX1 分數", "BOX1 項目", "BOX2 分數", "BOX2 項目", 
    "BOX3 分數", "BOX3 項目", "BOX4 分數", "BOX4 項目",
    "BOX5 分數", "BOX5 項目", "BOX6 分數", "BOX6 項目",
    "BOX7 分數", "BOX7 項目", "BOX8 分數", "BOX8 項目",
    "BOX9 分數", "BOX9 項目", "BOX10 分數", "BOX10 項目",
    "BOX11 分數", "BOX11 項目", "BOX12 分數", "BOX12 項目",
    "BOX13 分數", "BOX13 項目", "備註"
  ];

  const teamSummaryRows = [];
  const userDetailRows = [];

  sortedDates.forEach(date => {
    Object.keys(masterData[date]).forEach(teamName => {
      let teamTotal = 0;
      let teamCount = 0;
      const users = masterData[date][teamName];
      Object.keys(users).forEach(uid => {
        const u = users[uid];
        teamTotal += u.totalScore;
        teamCount++;

        // 核心：轉換成 [分數, 項目] 配對
        let rowDetail = [date, teamName, uid, u.name, u.totalScore, u.ts];
        console.log(u);
        u.boxes.forEach(val => {
          rowDetail.push(val); 
        });
        
        rowDetail.push(u.remark); 
        userDetailRows.push(rowDetail);
      });
      teamSummaryRows.push([date, teamName, teamCount, teamTotal, new Date()]);
    });
  });

  console.log(`準備寫入: 彙總 ${teamSummaryRows.length} 筆, 明細 ${userDetailRows.length} 筆`);

  // 執行寫入
  writeToSheet_(ss, summarySheetName, ["登記日期", "戰隊", "人數", "當日總分", "更新時間"], teamSummaryRows);
  writeToSheet_(ss, userDetailSheetName, userDetailHeaders, userDetailRows);
  
  SpreadsheetApp.flush();
}

/**
 * 工具：覆蓋寫入工作表
 */
function writeToSheet_(ss, name, headers, rows) {
  let sheet = ss.getSheetByName(name);
  if (!sheet) {
    sheet = ss.insertSheet(name);
  } else {
    sheet.clear();
  }
  sheet.appendRow(headers);
  if (rows.length > 0) {
    // 自動計算寬度確保不報錯
    sheet.getRange(2, 1, rows.length, rows[0].length).setValues(rows);
  }
  sheet.setFrozenRows(1);
}