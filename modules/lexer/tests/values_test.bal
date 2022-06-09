import ballerina/test;

@test:Config {
    dataProvider: simpleDataValueDataGen,
    groups: ["lexer"]
}
function testSimpleDataValueToken(string testingLine, TOMLToken expectedToken, string expectedLexeme) returns error? {
    LexerState state = setLexerString(testingLine, EXPRESSION_VALUE);
    check assertToken(state, expectedToken, lexeme = expectedLexeme);
}

function simpleDataValueDataGen() returns map<[string, TOMLToken, string]> {
    return {
        "positive decimal": ["+1", DECIMAL, "+1"],
        "negative decimal": ["-1", DECIMAL, "-1"],
        "unsigned decimal": ["1", DECIMAL, "1"],
        "zero decimal": ["0", DECIMAL, "0"],
        "underscore decimal": ["111_222_333", DECIMAL, "111222333"],
        "underscore hexadecimal": ["0xdead_beef", HEXADECIMAL, "deadbeef"],
        "underscore binary": ["0b001_010", BINARY, "001010"],
        "underscore octal": ["0o007_610", OCTAL, "007610"],
        "boolean true": ["true", BOOLEAN, "true"],
        "boolean false": ["false", BOOLEAN, "false"],
        "positive infinity": ["+inf", INFINITY, "+inf"],
        "negative infinity": ["-inf", INFINITY, "-inf"],
        "unsigned infinity": ["inf", INFINITY, "+inf"],
        "positive nan": ["+nan", NAN, ""],
        "negative nan": ["-nan", NAN, ""],
        "unsigned nan": ["nan", NAN, ""],
        "simple exponential": ["e", EXPONENTIAL, ""],
        "capital exponential": ["E", EXPONENTIAL, ""],
        "basic string": ["\"someValue\"", BASIC_STRING, "someValue"],
        "literal string": ["'someValue'", LITERAL_STRING, "someValue"]
    };
}

@test:Config {
    dataProvider: tokensAfterDecimalDataGen,
    groups: ["lexer"]
}
function testTokensAfterDecimal(string line, TOMLToken expectedToken) returns error? {
    LexerState state = setLexerString(line, EXPRESSION_VALUE);
    check assertToken(state, expectedToken, 2);
}

function tokensAfterDecimalDataGen() returns map<[string, TOMLToken]> {
    return {
        "exponential": ["123e2", EXPONENTIAL],
        "decimal": ["123.123", DOT]
    };
}

@test:Config {
    dataProvider: escapedCharacterDataGen,
    groups: ["lexer"]
}
function testEscapedCharacterToken(string lexeme, string value) returns error? {
    LexerState state = setLexerString("\"\\" + lexeme + "\"");
    check assertToken(state, BASIC_STRING, lexeme = value);
}

function escapedCharacterDataGen() returns map<[string, string]> {
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
    dataProvider: invalidEscapedCharDataGen,
    groups: ["lexer"]
}
function testInvalidEscapedCharacter(string lexeme) {
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

@test:Config {
    dataProvider: arrayValueDataGen,
    groups: ["lexer"]
}
function testArrayValue(string testingLine, TOMLToken expectedToken, int number, string expectedLexeme) returns error? {
    LexerState state = setLexerString(testingLine, EXPRESSION_VALUE);
    check assertToken(state, expectedToken, number);
}

function arrayValueDataGen() returns map<[string, TOMLToken, int, string]> {
    return {
        "starting array delimiter": ["[", OPEN_BRACKET, 0, ""],
        "ending array delimiter": ["]", CLOSE_BRACKET, 0, ""],
        "starting inline table delimiter": ["{", INLINE_TABLE_OPEN, 0, ""],
        "ending inline table delimiter": ["}", INLINE_TABLE_CLOSE, 0, ""],
        "same integers": ["[1, 2]", SEPARATOR, 3, ""],
        "string": ["[\"1\", 2]", SEPARATOR, 3, ""],
        "boolean": ["[true, 2]", SEPARATOR, 3, ""],
        "float": ["[1.0, 2]", SEPARATOR, 5, ""],
        "nested array": ["[[1], 2]", SEPARATOR, 5, ""]
    };
}

@test:Config {
    dataProvider: multilineTextDataGen,
    groups: ["lexer"]
}
function testMutltilineString(string testLine, Context testingState, TOMLToken expectedToken, int number, string expectedLexeme) returns error? {
    LexerState state = setLexerString(testLine, testingState);
    check assertToken(state, expectedToken, number, expectedLexeme);
}

function multilineTextDataGen() returns map<[string, Context, TOMLToken, int, string]> {
    return {
        "escape": ["\"\"\"escape\\  whitespace\"\"\"", MULTILINE_BASIC_STRING, MULTILINE_BASIC_STRING_ESCAPE, 3, ""],
        "valid quotes": ["\"\"\"single-quote\"double-quotes\"\"single-apastrophe'double-appastrophe''\"\"\"", MULTILINE_BASIC_STRING, MULTILINE_BASIC_STRING_LINE, 2, "single-quote\"double-quotes\"\"single-apastrophe'double-appastrophe''"],
        "literal": ["'''somevalue'''", MULTILINE_LITERAL_STRING, MULTILINE_LITERAL_STRING_LINE, 2, "somevalue"],
        "literal delimiter": ["'''", EXPRESSION_VALUE, MULTILINE_LITERAL_STRING_DELIMITER, 0, ""],
        "basic": ["\"\"\"somevalue\"\"\"", MULTILINE_BASIC_STRING, MULTILINE_BASIC_STRING_LINE, 2, "somevalue"],
        "basic delimiter": ["\"\"\"", EXPRESSION_VALUE, MULTILINE_BASIC_STRING_DELIMITER, 0, ""]
    };
}
