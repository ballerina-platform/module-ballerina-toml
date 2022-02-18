import ballerina/test;

@test:Config {}
function testMultiLineDelimiter() returns error? {
    Lexer lexer = setLexerString("\"\"\"");
    check assertToken(lexer, MULTI_BSTRING_DELIMITER);
}

@test:Config {}
function testMultiLineBasicStringChars() returns error? {
    Lexer lexer = setLexerString("\"\"\"somevalues\"\"\"");
    lexer.state = MULTILINE_BSTRING;
    check assertToken(lexer, MULTI_BSTRING_CHARS, 2, "somevalues");
}

@test:Config {}
function testValidQuotesInBasicMultilineString() returns error? {
    Lexer lexer = setLexerString("\"\"\"single-quote\"double-quotes\"\"single-apastrophe'double-appastrophe''\"\"\"");
    lexer.state = MULTILINE_BSTRING;
    check assertToken(lexer, MULTI_BSTRING_CHARS, 2, "single-quote\"double-quotes\"\"single-apastrophe'double-appastrophe''");
}

@test:Config {}
function testValidQuotesWithNewlinesBasicMultilineString() returns error? {
    AssertKey ak = check new AssertKey("multi_quotes", true);
    ak.hasKey("str1", "single-quote\" \\ndouble-quotes\"\" \\nsingle-apastrophe' \\ndouble-appastrophe'' \\n").close();
}

@test:Config {}
function testMultilineEscape() returns error? {
    Lexer lexer = setLexerString("\"\"\"escape\\  whitespace\"\"\"");
    lexer.state = MULTILINE_BSTRING;
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
function testDelimiterInsideMultilineBasicString() {
    assertParsingError("str1 = \"\"\"\"\"\"\"\"\"");
}

@test:Config {}
function testMultiLiteralStringDelimiter() returns error? {
    Lexer lexer = setLexerString("'''");
    check assertToken(lexer, MULTI_LSTRING_DELIMITER);
}

@test:Config {}
function testMultilineLiteralString() returns error? {
    Lexer lexer = setLexerString("'''somevalue'''");
    lexer.state = MULITLINE_LSTRING;
    check assertToken(lexer, MULTI_LSTRING_CHARS, 2, "somevalue");
}

@test:Config {}
function testDelimiterInsideTheMultilinneLiteralString() {
    assertParsingError("str1 = '''''''''");
}

@test:Config {}
function testValidMultiLineLiteralString() returns error? {
    AssertKey ak = check new AssertKey("str = '''somevalue'''");
    ak.hasKey("str", "somevalue").close();
}

@test:Config {}
function testValidApostropheInMultilineLiteralString() returns error? {
    AssertKey ak = check new AssertKey("str = '''single'double'''''");
    ak.hasKey("str", "single'double''").close();
}

@test:Config {}
function testMultilineLiteralStrinsNewLines() returns error? {
    AssertKey ak = check new AssertKey("multi_literal", true);
    ak.hasKey("str1", "single' \\ndouble''\\n").close();
}