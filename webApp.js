/**
 * 網頁入口控制（Apps Script 僅承擔「提供 HTML」的角色）
 *
 * 變更說明（2026-04-20 遷移至 Supabase）：
 *   - 移除 getMemberList / saveForm / getUserStatus / getPersonalHistory
 *     （這些 CRUD 邏輯改由前端 JS 直接呼叫 Supabase，見 supabase-client.html）
 *   - 保留 doGet：路由 + URL 參數注入 + Supabase 設定注入
 *   - 保留 storeCurrentUser / getCurrentUser（相容既有歷史頁設計）
 */

/**
 * 主路由：根據 ?page= 參數選擇 HTML 檔
 */
function doGet(e) {
    const request = e || { parameter: {} };
    const params = request.parameter || {};
    const page = params.page || 'Index';

    try {
        const template = HtmlService.createTemplateFromFile(page);

        // 使用者資訊（從 URL 參數取得，維持原本架構）
        template.user = {
            id:       params.id       || "",
            name:     params.name     || "",
            team:     params.team     || "",
            teamCode: params.teamCode || "",
            memberId: params.memberId || ""   // Supabase 的 members.id（BIGINT）
        };

        template.name = params.name || '';
        template.team = params.team || '';

        // 注入 Supabase 環境設定，讓 supabase-client.html 可以讀到
        template.supabaseUrl = SUPABASE_URL;
        template.supabaseKey = SUPABASE_ANON_KEY;

        // 保留 UserProperties 暫存機制（供歷史頁 getCurrentUser 使用）
        storeCurrentUser(params.id || "", params.name || "航海士");

        return template.evaluate()
            .setTitle('ONE PIECE-海洋親證班計分系統')
            .addMetaTag('viewport', 'width=device-width, initial-scale=1.0')
            .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
    } catch (err) {
        return HtmlService.createHtmlOutput(
            "頁面載入失敗，請確認 HTML 檔案名稱是否正確。錯誤：" + err.message
        );
    }
}

/**
 * 取得目前登入使用者（供歷史頁面使用，若需要動態取得而非模板注入）
 */
function getCurrentUser() {
    try {
        const props = PropertiesService.getUserProperties();
        const id    = props.getProperty('currentUserId')   || "";
        const name  = props.getProperty('currentUserName') || "航海士";
        return { id: id, name: name };
    } catch (err) {
        console.error("getCurrentUser 失敗: " + err.message);
        return { id: "", name: "航海士" };
    }
}

/**
 * 將使用者資訊存入 UserProperties（在 doGet 執行時呼叫）
 */
function storeCurrentUser(id, name) {
    const props = PropertiesService.getUserProperties();
    props.setProperty('currentUserId',   id   || "");
    props.setProperty('currentUserName', name || "航海士");
}
