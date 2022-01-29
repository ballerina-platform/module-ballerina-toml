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
    check assertToken(lexer, INTEGER, lexeme = "+0");

    lexer = setLexerString("-0", EXPRESSION_VALUE);
    check assertToken(lexer, INTEGER, lexeme = "-0");
}

@test:Config {}
function testUnderscoreDecimal() returns error? {
    Lexer lexer = setLexerString("111_222_333", EXPRESSION_VALUE);
    check assertToken(lexer, INTEGER, lexeme = "111222333");

    lexer = setLexerString("0xdead_beef", EXPRESSION_VALUE);
    check assertToken(lexer, INTEGER, lexeme = "0xdeadbeef");

    lexer = setLexerString("0b001_010", EXPRESSION_VALUE);
    check assertToken(lexer, INTEGER, lexeme = "0b001010");

    lexer = setLexerString("0o007_610", EXPRESSION_VALUE);
    check assertToken(lexer, INTEGER, lexeme = "0o007610");
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

    lexer = setLexerString("+inf", EXPRESSION_VALUE);
    check assertToken(lexer, INFINITY, lexeme = "+inf");

    lexer = setLexerString("-inf", EXPRESSION_VALUE);
    check assertToken(lexer, INFINITY, lexeme = "-inf");
}

@test:Config {}
function testNanToken() returns error? {
    Lexer lexer = setLexerString("nan", EXPRESSION_VALUE);
    check assertToken(lexer, NAN);

    lexer = setLexerString("+nan", EXPRESSION_VALUE);
    check assertToken(lexer, NAN);

    lexer = setLexerString("-nan", EXPRESSION_VALUE);
    check assertToken(lexer, NAN);
}

@test:Config {}
function testExponentialToken() returns error? {
    Lexer lexer = setLexerString("e", EXPRESSION_VALUE);
    check assertToken(lexer, EXPONENTIAL);

    lexer = setLexerString("E", EXPRESSION_VALUE);
    check assertToken(lexer, EXPONENTIAL);
}

@test:Config {}
function testExponentialTokenWithInteger() returns error? {
    Lexer lexer = setLexerString("123e2", EXPRESSION_VALUE);
    check assertToken(lexer, EXPONENTIAL, 2);
}

@test:Config {}
function testDecimalToken() returns error? {
    Lexer lexer = setLexerString("123.123", EXPRESSION_VALUE);
    check assertToken(lexer, DOT, 2);
}

@test:Config {}
function testProcessFractionalNumbers() returns error? {
    AssertKey ak = check new AssertKey("float_fractional", true);
    ak.hasKey("flt1", 1.0).hasKey("flt2", 3.14).hasKey("flt3", -0.1).close();
}

@test:Config {}
function testPorcessExponentialNumbers() returns error? {
    AssertKey ak = check new AssertKey("float_exponential", true);
    ak.hasKey("flt1", 500.0).hasKey("flt2", -0.02).close();
}

@test:Config {}
function testInvalidDecimalPoint() {
    assertParsingError("flt = .1");
    assertParsingError("flt = 1.");
    assertParsingError("flt = 1.e+20");
}

@test:Config {}
function testFloatWithUnderscore() returns error? {
    AssertKey ak = check new AssertKey("flt = 123_456.123_456");
    ak.hasKey("flt", 123456.123456).close();
}
