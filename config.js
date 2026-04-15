// 環境變數設定
//
// 優先使用 Script Properties（可在 Apps Script「專案設定 → 指令碼屬性」覆寫），
// 沒設定時使用下方預設值（正式環境 Sheet ID）。
// 這樣同一份程式碼可以在【正式】與【測試】兩個 Apps Script 專案共用。
//
// 設定方式：
//   Apps Script 左側「專案設定 ⚙️ → 指令碼屬性 → 新增指令碼屬性」
//     SS_ID_MEMBER = <測試 Sheet ID>
//     SS_ID_SCORE  = <測試 Sheet ID>

const PROPS = PropertiesService.getScriptProperties();

/**
 * google sheet ID settings
 */
const SS_ID_MEMBER = PROPS.getProperty('SS_ID_MEMBER') || '1CFTaHNqlaVQOC7Bpuk7KMznFRuAYNHmBMxeDvA19wtw'; // 人員總表 ID
const SS_ID_SCORE  = PROPS.getProperty('SS_ID_SCORE')  || '1CFTaHNqlaVQOC7Bpuk7KMznFRuAYNHmBMxeDvA19wtw'; // 分數登記試算表 ID

const SHEET_NAME_MEMBER = '人員總表';

/**
 * 隊編與 google sheet mapping(對照表)
 */
const TEAM_MAP = {
    "T01": "第一大隊",
    "T02": "第二大隊",
    "T03": "第三大隊",
    "T04": "第四大隊",
    "T05": "第五大隊",
};
