import ballerina/test;

@test:Config {
    dataProvider: dateTimeDataGen
}
function testDateTimeToken(string testingLine, TOMLToken expectedToken) returns error? {
    setLexerString(testingLine, DATE_TIME);
    check assertToken(expectedToken, 2);
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

@test:Config {}
function testDateTimeSimilarSyntax() returns error? {
    setLexerString("[1, \"-\"]", EXPRESSION_VALUE);
    check assertToken(DECIMAL, 2);
    check assertToken(BASIC_STRING, 2);
}
