import ballerina/test;
import ballerina/time;

@test:Config {}
function testDateTimeSeparatorTokens() returns error? {
    Lexer lexer = setLexerString("12:12", NUMBER);
    check assertToken(lexer, COLON, 2);

    lexer = setLexerString("1982-12", NUMBER);
    check assertToken(lexer, MINUS, 2);
}

@test:Config {}
function testTimeDelimiterTokens() returns error? {
    Lexer lexer = setLexerString("12t12", NUMBER);
    check assertToken(lexer, TIME_DELIMITER, 2);

    lexer = setLexerString("12T12", NUMBER);
    check assertToken(lexer, TIME_DELIMITER, 2);

    lexer = setLexerString("12 12", NUMBER);
    check assertToken(lexer, TIME_DELIMITER, 2);
}

@test:Config {}
function testTimeOffsetTokens() returns error? {
    Lexer lexer = setLexerString("10+7:30", NUMBER);
    check assertToken(lexer, PLUS, 2);

    lexer = setLexerString("10-6:30", NUMBER);
    check assertToken(lexer, MINUS, 2);

    lexer = setLexerString("10Z", NUMBER);
    check assertToken(lexer, ZULU, 2);
}

@test:Config {}
function testDateTimeSimilarSyntax() returns error? {
    Lexer lexer = setLexerString("arr = [1, \"-\"]");
    check assertToken(lexer, DECIMAL, 4);
    check assertToken(lexer, BASIC_STRING, 2);
}

@test:Config {}
function testODTZulu() returns error? {
    AssertKey ak = check new AssertKey("odt = 1979-05-27T07:32:00Z");
    ak.hasKey("odt", check time:utcFromString("1979-05-27T07:32:00Z")).close();
}

@test:Config {}
function testInvalidODT() {
    assertParsingError("odt = 1979-05-2707:32:00Z");
    assertParsingError("odt = 1979-05-2707:32:00-");
}

@test:Config {}
function testODTTimeDifferenceOffset() returns error? {
    AssertKey ak = check new AssertKey("odt = 1979-05-27T00:32:00-07:00");
    ak.hasKey("odt", check time:utcFromString("1979-05-27T07:32:00Z")).close();
}

@test:Config {}
function testODTSecondFraction() returns error? {
    AssertKey ak = check new AssertKey("odt = 1979-05-27T07:32:00.99");
    ak.hasKey("odt", check time:utcFromString("1979-05-27T07:32:00.99Z")).close();
}

@test:Config {}
function testODTSecondFractionWithDifferenceOffset() returns error? {
    AssertKey ak = check new AssertKey("odt = 1979-05-27T07:32:00.99+07:00");
    ak.hasKey("odt", check time:utcFromString("1979-05-27T00:32:00.99Z")).close();
}

@test:Config {}
function testODTSupportDifferentTimeDelimiters() returns error? {
    AssertKey ak = check new AssertKey("date_time_delim", true);
    ak.hasKey("odt1", "1979-05-27T07:32:00")
        .hasKey("odt2", "1979-05-27T07:32:00")
        .hasKey("odt3", "1979-05-27T07:32:00")
        .close();
}

@test:Config {}
function testLocalDate() returns error? {
    AssertKey ak = check new AssertKey("ld = 1922-12-12");
    ak.hasKey("ld", "1922-12-12").close();
}

@test:Config {}
function testInvalidLocalDate() {
    assertParsingError("192-12-12");
    assertParsingError("1922-2-12");
    assertParsingError("1922-02-2");
    assertParsingError("1922-2-");
    assertParsingError("1922--1");
    assertParsingError("-02-01");
}

@test:Config {}
function testLocalTime() returns error? {
    AssertKey ak = check new AssertKey("lt = 07:32:00");
    ak.hasKey("lt", "07:32:00").close();
}

@test:Config {}
function testLocalTimeWithFraction() returns error? {
    AssertKey ak = check new AssertKey("lt = 07:32:00.99");
    ak.hasKey("lt", "07:32:00.99").close();
}

@test:Config {}
function testInvalidLocalTime() {
    assertParsingError("7:32:00");
    assertParsingError("07:2:00");
    assertParsingError("07:02:1");
    assertParsingError(":02:01");
    assertParsingError("07::01");
    assertParsingError("07:02:");
    assertParsingError("07:32:0099");
}

@test:Config {}
function testLocalDateTime() returns error? {
    AssertKey ak = check new AssertKey("ldt = 1979-05-27T07:32:00");
    ak.hasKey("ldt", "1979-05-27T07:32:00").close();
}
