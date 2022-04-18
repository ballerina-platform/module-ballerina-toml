import ballerina/test;

@test:Config {
    dataProvider: tableDelimiterDataGen
}
function testTableDelimiterToken(string testingLine, TOMLToken expectedToken) returns error? {
    LexerState state = setLexerString(testingLine);
    check assertToken(state,expectedToken);
}

function tableDelimiterDataGen() returns map<[string, TOMLToken]> {
    return {
        "starting array table token": ["[[", ARRAY_TABLE_OPEN],
        "closing array table token": ["]]", ARRAY_TABLE_CLOSE],
        "starting table token": ["[", OPEN_BRACKET],
        "closing table token": ["]", CLOSE_BRACKET]
    };
}