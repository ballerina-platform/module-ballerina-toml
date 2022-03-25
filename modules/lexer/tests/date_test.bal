import ballerina/test;

@test:Config {}
function testDateTimeSeparatorTokens() returns error? {
    setLexerString("12:12", DATE_TIME);
    check assertToken(COLON, 2);

    setLexerString("1982-12", DATE_TIME);
    check assertToken(MINUS, 2);
}

@test:Config {}
function testTimeDelimiterTokens() returns error? {
    setLexerString("12t12", DATE_TIME);
    check assertToken(TIME_DELIMITER, 2);

    setLexerString("12T12", DATE_TIME);
    check assertToken(TIME_DELIMITER, 2);

    setLexerString("12 12", DATE_TIME);
    check assertToken(TIME_DELIMITER, 2);
}

@test:Config {}
function testTimeOffsetTokens() returns error? {
    setLexerString("10+7:30", DATE_TIME);
    check assertToken(PLUS, 2);

    setLexerString("10-6:30", DATE_TIME);
    check assertToken(MINUS, 2);

    setLexerString("10Z", DATE_TIME);
    check assertToken(ZULU, 2);
}

@test:Config {}
function testDateTimeSimilarSyntax() returns error? {
    setLexerString("[1, \"-\"]", EXPRESSION_VALUE);
    check assertToken(DECIMAL, 2);
    check assertToken(BASIC_STRING, 2);
}
