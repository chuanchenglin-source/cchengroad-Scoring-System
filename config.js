// 環境變數設定

/**
 * google sheet ID settings
 */
const SS_ID_MEMBER = '1CFTaHNqlaVQOC7Bpuk7KMznFRuAYNHmBMxeDvA19wtw'; // 人員總表 ID
const SS_ID_SCORE = '1CFTaHNqlaVQOC7Bpuk7KMznFRuAYNHmBMxeDvA19wtw';  // 分數登記試算表 ID

/**
 * 偵查官扣分記錄 Sheet ID
 * - 正式環境：空字串（合併 PR 後由主工程師改成正式偵查官 Sheet ID）
 * - 副本環境：'1_bkaXcApXPKe9I1kF0DL4gne06e__8YiC5yy5FOgT3Y'（偵查官系統 0527）
 * - 為空字串時 getPersonalHistory 會 fallback 為「無扣分」狀態，不影響既有功能
 */
const SS_ID_MONITOR_DEDUCTION = '';

const SHEET_NAME_MEMBER = '人員總表';
const SHEET_NAME_DEDUCTION = '扣分記錄';

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