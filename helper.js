function getScriptUrl() {
    return ScriptApp.getService().getUrl();
}

function include(filename) {
    return HtmlService.createHtmlOutputFromFile(filename).getContent();
}
