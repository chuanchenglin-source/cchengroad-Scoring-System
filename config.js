// =====================================================
// 環境變數設定
// =====================================================
//
// 本檔定義 Supabase 連線所需的 URL / anon key
//
// 優先從 Script Properties 讀取（可在 Apps Script「專案設定 → 指令碼屬性」設定），
// 沒設定時使用下方預設值。
//
// ⚠️ 正式環境建議在 Script Properties 設值，不要寫在程式碼裡。
//    設定方式：
//      Apps Script 左側「專案設定 ⚙️ → 指令碼屬性 → 新增指令碼屬性」
//        SUPABASE_URL       = https://xxxxx.supabase.co
//        SUPABASE_ANON_KEY  = eyJhbGci...
// =====================================================

const PROPS = PropertiesService.getScriptProperties();

/**
 * Supabase 連線設定
 */
const SUPABASE_URL = PROPS.getProperty('SUPABASE_URL')
    || 'https://ygpaipsdwiaaxdbghemb.supabase.co';

const SUPABASE_ANON_KEY = PROPS.getProperty('SUPABASE_ANON_KEY')
    || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlncGFpcHNkd2lhYXhkYmdoZW1iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY2NDczOTEsImV4cCI6MjA5MjIyMzM5MX0.0W5vHYUOpT0fM307Vq7d4fjTd9gj0ncKChs744vWZ5k';
