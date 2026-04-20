/**
 * 取得此 Apps Script Web App 的 URL（供前端跳頁用）
 */
function getScriptUrl() {
    return ScriptApp.getService().getUrl();
}

/**
 * include：在 HTML 模板中引入另一個 HTML 檔
 * ⚠️ 必須用 createTemplateFromFile（不是 createHtmlOutputFromFile），
 *    否則被引入檔案裡的 <?= ?> 不會被處理。
 * 額外注入 Supabase 環境變數，讓 supabase-client.html 可以讀到。
 */
function include(filename) {
    const template = HtmlService.createTemplateFromFile(filename);
    template.supabaseUrl = SUPABASE_URL;
    template.supabaseKey = SUPABASE_ANON_KEY;
    return template.evaluate().getContent();
}
