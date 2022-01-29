import ballerina/test;

// String tokens
@test:Config {}
function testBasicString() returns error? {
    Lexer lexer = setLexerString("someKey = \"someValue\"");
    check assertToken(lexer, BASIC_STRING, 3, "someValue");
}

@test:Config {}
function testLiteralString() returns error? {
    Lexer lexer = setLexerString("somekey = 'somevalue'");
    check assertToken(lexer, LITERAL_STRING, 3, "somevalue");
}

@test:Config {}
function testUnclosedString() {
    assertLexicalError("'hello");
}

// Integer tokens
@test:Config {}
function testPositiveDecimal() returns error? {
    Lexer lexer = setLexerString("+1", EXPRESSION_VALUE);
    check assertToken(lexer, INTEGER, lexeme = "+1");
}

@test:Config {}
function testNegativeDecimal() returns error? {
    Lexer lexer = setLexerString("-1", EXPRESSION_VALUE);
    check assertToken(lexer, INTEGER, lexeme = "-1");
}

@test:Config {}
function testDecimal() returns error? {
    Lexer lexer = setLexerString("1", EXPRESSION_VALUE);
    check assertToken(lexer, INTEGER, lexeme = "1");
}

@test:Config {}
function testDecimalZero() returns error? {
    Lexer lexer = setLexerString("0", EXPRESSION_VALUE);
    check assertToken(lexer, INTEGER, lexeme = "0");

    lexer = setLexerString("+0", EXPRESSION_VALUE);
    check assertToken(lexer, INTEGER, lexeme = "0");

    lexer = setLexerString("-0", EXPRESSION_VALUE);
    check assertToken(lexer, INTEGER, lexeme = "0");
}

@test:Config {}
function testUnderscoreDecimal() returns error? {
    Lexer lexer = setLexerString("111_222_333", EXPRESSION_VALUE);
    check assertToken(lexer, INTEGER, lexeme = "111_222_333");

    lexer = setLexerString("0xdead_beef", EXPRESSION_VALUE);
    check assertToken(lexer, INTEGER, lexeme = "0xdead_beef");

    lexer = setLexerString("0b001_010", EXPRESSION_VALUE);
    check assertToken(lexer, INTEGER, lexeme = "0b001_010");

    lexer = setLexerString("0o007_610", EXPRESSION_VALUE);
    check assertToken(lexer, INTEGER, lexeme = "0o007_610");
}

@test:Config {}
function testIllegalUnderscoe() {
    assertParsingError("somekey = _1", isLexical = true);
    assertParsingError("somekey = 1_", isLexical = true);
}

@test:Config {}
function testLeadingZeroDecimal() {
    assertParsingError("somekey = 012", isLexical = true);
}

@test:Config {}
function testProcessIntegerValue() returns error? {
    AssertKey ak = check new AssertKey("somekey = 123");
    ak.hasKey("somekey", 123).close();
}

// Boolean tokens
@test:Config {}
function testBooleanValues() returns error? {
    Lexer lexer = setLexerString("true", EXPRESSION_VALUE);
    check assertToken(lexer, BOOLEAN, lexeme = "true");

    lexer = setLexerString("false", EXPRESSION_VALUE);
    check assertToken(lexer, BOOLEAN, lexeme = "false");
}

@test:Config {}
function testProcessBooleanValues() returns error? {
    AssertKey ak = check new AssertKey("somekey = true");
    ak.hasKey("somekey", true).close();
}

@test:Config {}
function testInfinityToken() returns error? {
    Lexer lexer = setLexerString("inf", EXPRESSION_VALUE);
    check assertToken(lexer, INFINITY, lexeme = "+inf");

    lexer = setLexerString("+inf");
    check assertToken(lexer, INFINITY, lexeme = "+inf");

    lexer = setLexerString("-inf");
    check assertToken(lexer, INFINITY, lexeme = "-inf");
}

@test:Config {}
function testNanToken() returns error? {
    Lexer lexer = setLexerString("nan", EXPRESSION_VALUE);
    check assertToken(lexer, NAN, lexeme = "+nan");

    lexer = setLexerString("+nan", EXPRESSION_VALUE);
    check assertToken(lexer, NAN, lexeme = "+nan");

    lexer = setLexerString("-nan", EXPRESSION_VALUE);
    check assertToken(lexer, NAN, lexeme = "-nan");
}
