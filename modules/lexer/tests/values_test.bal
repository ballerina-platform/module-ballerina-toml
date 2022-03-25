import ballerina/test;

// String tokens
@test:Config {}
function testBasicString() returns error? {
    setLexerString("someKey = \"someValue\"");
    check assertToken(BASIC_STRING, 3, "someValue");
}

@test:Config {}
function testLiteralString() returns error? {
    setLexerString("somekey = 'somevalue'");
    check assertToken(LITERAL_STRING, 3, "somevalue");
}

@test:Config {}
function testUnclosedString() {
    assertLexicalError("'hello");
}

// DECIMAL tokens
@test:Config {}
function testPositiveDecimal() returns error? {
    setLexerString("+1", EXPRESSION_VALUE);
    check assertToken(DECIMAL, lexeme = "+1");
}

@test:Config {}
function testNegativeDecimal() returns error? {
    setLexerString("-1", EXPRESSION_VALUE);
    check assertToken(DECIMAL, lexeme = "-1");
}

@test:Config {}
function testDecimal() returns error? {
    setLexerString("1", EXPRESSION_VALUE);
    check assertToken(DECIMAL, lexeme = "1");
}

@test:Config {}
function testDecimalZero() returns error? {
    setLexerString("0", EXPRESSION_VALUE);
    check assertToken(DECIMAL, lexeme = "0");

    setLexerString("+0", EXPRESSION_VALUE);
    check assertToken(DECIMAL, lexeme = "+0");

    setLexerString("-0", EXPRESSION_VALUE);
    check assertToken(DECIMAL, lexeme = "-0");
}

@test:Config {}
function testUnderscoreDecimal() returns error? {
    setLexerString("111_222_333", EXPRESSION_VALUE);
    check assertToken(DECIMAL, lexeme = "111222333");

    setLexerString("0xdead_beef", EXPRESSION_VALUE);
    check assertToken(HEXADECIMAL, lexeme = "deadbeef");

    setLexerString("0b001_010", EXPRESSION_VALUE);
    check assertToken(BINARY, lexeme = "001010");

    setLexerString("0o007_610", EXPRESSION_VALUE);
    check assertToken(OCTAL, lexeme = "007610");
}

// Boolean tokens
@test:Config {}
function testBooleanValues() returns error? {
    setLexerString("true", EXPRESSION_VALUE);
    check assertToken(BOOLEAN, lexeme = "true");

    setLexerString("false", EXPRESSION_VALUE);
    check assertToken(BOOLEAN, lexeme = "false");
}


@test:Config {}
function testInfinityToken() returns error? {
    setLexerString("inf", EXPRESSION_VALUE);
    check assertToken(INFINITY, lexeme = "+inf");

    setLexerString("+inf", EXPRESSION_VALUE);
    check assertToken(INFINITY, lexeme = "+inf");

    setLexerString("-inf", EXPRESSION_VALUE);
    check assertToken(INFINITY, lexeme = "-inf");
}

@test:Config {}
function testNanToken() returns error? {
    setLexerString("nan", EXPRESSION_VALUE);
    check assertToken(NAN);

    setLexerString("+nan", EXPRESSION_VALUE);
    check assertToken(NAN);

    setLexerString("-nan", EXPRESSION_VALUE);
    check assertToken(NAN);
}

@test:Config {}
function testExponentialToken() returns error? {
    setLexerString("e", EXPRESSION_VALUE);
    check assertToken(EXPONENTIAL);

    setLexerString("E", EXPRESSION_VALUE);
    check assertToken(EXPONENTIAL);
}

@test:Config {}
function testExponentialTokenWithDECIMAL() returns error? {
    setLexerString("123e2", EXPRESSION_VALUE);
    check assertToken(EXPONENTIAL, 2);
}

@test:Config {}
function testDecimalToken() returns error? {
    setLexerString("123.123", EXPRESSION_VALUE);
    check assertToken(DOT, 2);
}

@test:Config {
    dataProvider: excapedCharacterDataGen
}
function testEscapedCharacterToken(string lexeme, string value) returns error? {
    setLexerString("\"\\"+ lexeme + "\"");
    check assertToken(BASIC_STRING, lexeme = value);
}

function excapedCharacterDataGen() returns map<[string, string]> {
    return {
        "backspace": ["b", "\u{08}"],
        "tab": ["t", "\t"],
        "linefeed": ["n", "\n"],
        "form-feed": ["f", "\u{0c}"],
        "carriage-return": ["r", "\r"],
        "double-quote": ["\"", "\""],
        "backslash": ["\\", "\\"],
        "u-4": ["u0041", "A"],
        "U-8": ["U00000041", "A"]
    };
}

@test:Config {
    dataProvider: invalidEscapedCharDataGen
}
function testInvalidExcapedCharacter(string lexeme) {
    assertLexicalError("\\" + lexeme);
}

function invalidEscapedCharDataGen() returns map<[string]> {
    return {
        "u-3": ["u333"],
        "u-5": ["u55555"],
        "U-7": ["u7777777"],
        "U-9": ["u999999999"],
        "no-char": [""],
        "invalid-char": ["z"]
    };
}
