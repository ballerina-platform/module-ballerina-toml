import ballerina/test;

@test:Config {}
function testMultiLineDelimiter() returns error? {
    Lexer lexer = setLexerString("\"\"\"");
    check assertToken(lexer, MULTI_BSTRING_DELIMITER);
}

@test:Config {}
function testMultiLineStringChars() returns error? {
    Lexer lexer = setLexerString("\"\"\"somevalues\"\"\"");
    lexer.state = MULTILINE_STRING;
    check assertToken(lexer, MULTI_BSTRING_CHARS, 2, "somevalues");
}

@test:Config {}
function testValidQuotesInMultiline() returns error? {
    Lexer lexer = setLexerString("\"\"\"single-quote\"double-quotes\"\"single-apastrophe'double-appastrophe''\"\"\"");
    lexer.state = MULTILINE_STRING;
    check assertToken(lexer, MULTI_BSTRING_CHARS, 2, "single-quote\"double-quotes\"\"single-apastrophe'double-appastrophe''");
}

@test:Config {}
function testValidQuotesWithNewlines() returns error? {
    AssertKey ak = check new AssertKey("multi_quotes", true);
    ak.hasKey("str1", "single-quote\" \\ndouble-quotes\"\" \\nsingle-apastrophe' \\ndouble-appastrophe'' \\n").close();
}

@test:Config {}
function testMultilineEscape() returns error? {
    Lexer lexer = setLexerString("\"\"\"escape\\  whitespace\"\"\"");
    lexer.state = MULTILINE_STRING;
    check assertToken(lexer, MULTI_BSTRING_ESCAPE, 3);
}

@test:Config {}
function testMultilineEscapeWhitespaces() returns error? {
    AssertKey ak = check new AssertKey("str1 = \"\"\"escape\\  whitespace\"\"\"");
    ak.hasKey("str1", "escapewhitespace").close();
}

@test:Config {}
function testMultilineEscapeNewlines() returns error? {
    AssertKey ak = check new AssertKey("multi_escape", true);
    ak.hasKey("str1", "escapewhitespace").close();
}

@test:Config {}
function testDelimiterInsideMultilineString() {
    assertParsingError("str1 = \"\"\"\"\"\"\"\"\"");
}
