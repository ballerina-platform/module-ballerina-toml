import ballerina/test;

@test:Config {
    dataProvider: dateTimeDataGen,
    groups: ["lexer"]
}
function testDateTimeToken(string testingLine, TOMLToken expectedToken) returns error? {
    LexerState state = setLexerString(testingLine, DATE_TIME);
    check assertToken(state, expectedToken, 2);
}

function dateTimeDataGen() returns map<[string, TOMLToken]> {
    return {
        "colon separator": ["12:12", COLON],
        "minus separator": ["1982-12", MINUS],
        "simple t delimiter": ["12t12", TIME_DELIMITER],
        "capital T delimiter": ["12T12", TIME_DELIMITER],
        "space delimiter": ["12 12", TIME_DELIMITER],
        "plus offset": ["10+7:30", PLUS],
        "minus offset": ["10-6:30", MINUS],
        "zulu offset": ["10Z", ZULU]
    };
}

@test:Config {
    groups: ["lexer"]
}
function testDateTimeSimilarSyntax() returns error? {
    LexerState state = setLexerString("[1, \"-\"]", EXPRESSION_VALUE);
    check assertToken(state, DECIMAL, 2);
    check assertToken(state, BASIC_STRING, 2);
}
