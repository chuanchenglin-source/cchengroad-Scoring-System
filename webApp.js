/**
 * 網頁入口控制
 */
function doGet(e) {
    const request = e || { parameter: {} };
    const params = request.parameter || {};
    const page = params.page || 'Index';

    try {
        const template = HtmlService.createTemplateFromFile(page);
    
        template.user = {
            id: params.id || "",
            name: params.name || "",
            team: params.team || "",
            teamCode: params.teamCode || "" 
        };
        
        template.name = params.name || '';
        template.team = params.team || '';

        return template.evaluate()
            .setTitle('ONE PIECE-海洋親證班計分系統')
            .addMetaTag('viewport', 'width=device-width, initial-scale=1.0')
            .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
    } catch (err) {
        return HtmlService.createHtmlOutput("頁面載入失敗，請確認 HTML 檔案名稱是否正確。錯誤：" + err.message);
    }
}

/**
 * [Index 頁面使用] 從人員總表抓取名單
 */
function getMemberList() {
  try {
    const ss = SpreadsheetApp.openById(SS_ID_MEMBER);
    const sheet = ss.getSheetByName(SHEET_NAME_MEMBER);
    if (!sheet) throw new Error("找不到工作表：" + SHEET_NAME_MEMBER);
    
    const data = sheet.getDataRange().getValues();
    data.shift(); // 移除標題列
    
    return data.map(row => ({
      teamCode: row[0] ? row[0].toString().trim() : "", // A欄: 隊編
      id: row[4] ? row[4].toString().trim() : "",       // E欄: ID
      name: row[3] ? row[3].toString().trim() : "",     // D欄: 姓名
      team: row[2] ? row[2].toString().trim() : "",     // C欄: 大隊全名
      mentor: row[5] ? row[5].toString().trim() : ""    // F欄: 大隊家長
    })).filter(m => m.name !== "");
    } catch (err) {
        console.error("讀取人員總表失敗: " + err.message);
        return [];
    }
}

/**
 * [main 頁面使用] 儲存所有 BOX 的細項與總分
 */
function saveForm(payload) {
    console.log("接收到前端資料內容:", JSON.stringify(payload));

    try {
        if (!payload || typeof payload !== 'object') {
            throw new Error("接收到的資料格式錯誤或為空 (Payload is invalid)");
        }

        const user = payload.user || {};
        const details = payload.details || {};
        const selectedDate = payload.selectedDate || "未提供日期";
        const totalScore = payload.totalScore || 0;

        if (!user.id) {
            throw new Error("身分識別失敗：缺少使用者 ID");
        }

        const ss = SpreadsheetApp.openById(SS_ID_SCORE);

        // 決定目標工作表名稱
        let teamCode = user.teamCode || user.id.substring(0, 3); 
        let targetSheetName = (typeof TEAM_MAP !== 'undefined' && TEAM_MAP[teamCode]) ? TEAM_MAP[teamCode] : "未分類分數";

        let sheet = ss.getSheetByName(targetSheetName);
    
        if (!sheet) {
          sheet = ss.insertSheet(targetSheetName);
          sheet.appendRow([
              "時間戳記", "使用者ID", "小隊", "姓名", "登記日期", "總分", 
              "BOX1(打拳)", "BOX2(調頻)", "BOX3(心得)", "BOX4(實體)", 
              "BOX5(巔峰)", "BOX6(素食)", "BOX7(系列)", "BOX8(社團)", 
              "BOX9(高階)", "BOX10(五運)", "BOX11(傳愛名單)", 
              "BOX12(全勤)", "BOX13(頻率)", "備註"
          ]);
        }

        sheet.appendRow([
          new Date(),               // A: 時間戳記
          user.id,                  // B: 使用者ID
          user.team || "",          // C: 小隊
          user.name || "",          // D: 姓名
          selectedDate,             // E: 登記日期
          totalScore,               // F: 總分
          details.box1_SCORE || "",     // G: BOX1 總分
          details.box1_CONTENT || "",   // H: BOX1 項目
          details.box2_SCORE || "",     // I: BOX2 總分
          details.box2_CONTENT || "",   // J: BOX2 項目
          details.box3_SCORE || "",     // K: BOX3 總分
          details.box3_CONTENT || "",   // L: BOX3 項目
          details.box4_SCORE || "",     // M: BOX4 總分
          details.box4_CONTENT || "",   // N: BOX4 項目
          details.box5_SCORE || "",     // O: BOX5 總分
          details.box5_CONTENT || "",   // P: BOX5 項目
          details.box6_SCORE || "",     // Q: BOX6 總分
          details.box6_CONTENT || "",   // R: BOX6 項目
          details.box7_SCORE || "",     // S: BOX7 總分
          details.box7_CONTENT || "",   // T: BOX7 項目
          details.box8_SCORE || "",     // U: BOX8 總分
          details.box8_CONTENT || "",   // V: BOX8 項目
          details.box9_SCORE || "",     // W: BOX9 總分
          details.box9_CONTENT || "",   // X: BOX9 項目
          details.box10_SCORE || "",    // Y: BOX10 總分
          details.box10_CONTENT || "",  // Z: BOX10 項目
          details.box11_SCORE || "",    // AA: BOX11 總分
          details.box11_CONTENT || "",  // AB: BOX11 項目
          details.box12_SCORE || "",    // AC: BOX12 總分
          details.box12_CONTENT || "",  // AD: BOX12 項目
          details.box13_SCORE || "",    // AE: BOX13 總分
          details.box13_CONTENT || "",  // AF: BOX13 項目
          details.box14 || ""        // AG: 備註 (對應前端的 remarks)
        ]);
        
        return { success: true, target: targetSheetName };
    } catch (e) {
        console.error("儲存失敗: " + e.toString());
        return { success: false, error: e.toString() };
    }
}

/**
 * 獲取使用者已完成登記的日期
 */
function getUserStatus(userId) {
  try {
    if (!userId) return [];
    const ss = SpreadsheetApp.openById(SS_ID_SCORE);
    const sheets = ss.getSheets();
    let completedDates = [];

    sheets.forEach(sheet => {
      const data = sheet.getDataRange().getValues();
      for (let i = 1; i < data.length; i++) {
        if (data[i][1] == userId) {
          const dateStr = data[i][4];
          if (dateStr && !completedDates.includes(dateStr)) {
            completedDates.push(dateStr);
          }
        }
      }
    });
    return completedDates;
  } catch (e) {
    return [];
  }
}

/**
 * 取得指定使用者的歷史填單紀錄
 */
function getPersonalHistory() {
  const SHEET_NAME = '每日個人分數結算';
  let userId ="T01_小巴_大心"
  
  try {
    const ss = SpreadsheetApp.openById(SS_ID_SCORE);
    const sheet = ss.getSheetByName(SHEET_NAME);
    const data = sheet.getDataRange().getValues();
    
    // 移除標題列
    const rows = data.slice(1);
    
    // 過濾出該使用者的資料
    const userRecords = rows.filter(row => String(row[2]) === String(userId));
    
    // 格式化資料以符合前端需求
    return userRecords.map(row => {
      // 處理日期：將 Google Date 物件轉為 YYYY-MM-DD 字串
      let dateStr = "";
      if (row[0] instanceof Date) {
        dateStr = Utilities.formatDate(row[0], Session.getScriptTimeZone(), "yyyy-MM-dd");
      } else {
        dateStr = String(row[0]);
      }

      // 建立基礎物件
      let record = {
        date: dateStr,
        team: row[1],        // B: 戰隊
        userId: row[2],      // C: ID
        userName: row[3],    // D: 姓名
        score: row[4],       // E: 採計分數
        originalTime: row[5],// F: 原始填寫時間
        remark: row[32]      // AG: 備註
      };

      // 動態對應 BOX 1 到 BOX 13 的分數與內容
      // 欄位規則：G,H 是 BOX1; I,J 是 BOX2 ... 以此類推
      for (let i = 1; i <= 13; i++) {
        const scoreIndex = 6 + (i - 1) * 2;   // G欄(Index 6)開始，每2格一組
        const contentIndex = 7 + (i - 1) * 2; // H欄(Index 7)開始
        
        record[`box${i}_score`] = row[scoreIndex];
        record[`box${i}_content`] = row[contentIndex];
      }
      
      // 特別處理 BOX 14 (原本欄位表只到 AG，若 BOX 14 是備註，則對應到 AG)
      // 這裡假設第 14 個 BOX 顯示的是備註內容
      record[`box14_score`] = 0; // 備註通常無分
      record[`box14_content`] = row[32]; // AG: 備註
      console.log(record)
      return record;
    });
    
  } catch (e) {
    Logger.log("Error in getPersonalHistory: " + e.toString());
    return [];
  }
}