// =====================================================
// ⚠️ 本檔案已停用（2026-04-20 遷移至 Supabase 後）
//
// 原本功能：rebuildSummaryReport() — 掃描所有大隊分頁，
//           產出「每日個人分數結算」「每日戰隊總分彙總」
//
// 新架構下：
//   - 每日結算由 Supabase 內建函式 finalize_daily_scores() 負責
//   - 彙總/排名由前端直接 SQL 查詢或透過 views 產生
//   - 此檔保留只為避免 Apps Script 觸發器遺失，請勿呼叫
// =====================================================

/**
 * @deprecated 已改由 Supabase finalize_daily_scores() 處理，本函式不再執行任何工作
 */
function rebuildSummaryReport() {
    console.log('[rebuildSummaryReport] DEPRECATED — 已遷移至 Supabase，本函式不再執行工作');
    return { deprecated: true };
}
