import ballerina/test;

@test:Config {}
function testMultiLineDelimiter() returns error? {
    setLexerString("\"\"\"");
    check assertToken(MULTI_BSTRING_DELIMITER);
}

@test:Config {}
function testMultiLineBasicStringChars() returns error? {
    setLexerString("\"\"\"somevalues\"\"\"");
    state = MULTILINE_BSTRING;
    check assertToken(MULTI_BSTRING_CHARS, 2, "somevalues");
}

@test:Config {}
function testValidQuotesInBasicMultilineString() returns error? {
    setLexerString("\"\"\"single-quote\"double-quotes\"\"single-apastrophe'double-appastrophe''\"\"\"");
    state = MULTILINE_BSTRING;
    check assertToken(MULTI_BSTRING_CHARS, 2, "single-quote\"double-quotes\"\"single-apastrophe'double-appastrophe''");
}

@test:Config {}
function testMultilineEscape() returns error? {
    setLexerString("\"\"\"escape\\  whitespace\"\"\"");
    state = MULTILINE_BSTRING;
    check assertToken(MULTI_BSTRING_ESCAPE, 3);
}