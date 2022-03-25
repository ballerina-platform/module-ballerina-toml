import ballerina/test;

@test:Config {}
function testFullLineComment() returns error? {
    setLexerString("# someComment");
    check assertToken(EOL);
}

@test:Config {}
function testEOLComment() returns error? {
    setLexerString("someKey = \"someValue\" # someComment");
    check assertToken(EOL, 4);
}

@test:Config {}
function testMultipleWhiteSpaces() returns error? {
    setLexerString("  ");
    check assertToken(EOL);
}

@test:Config {}
function testUnquotedKey() returns error? {
    setLexerString("somekey = \"Some Value\"");
    check assertToken(UNQUOTED_KEY, lexeme = "somekey");
}

@test:Config {}
function testUnquotedKeyWithInvalidChar() {
    assertLexicalError("some$value = 1");
}

@test:Config {}
function testKeyValueSeparator() returns error? {
    setLexerString("somekey = 1");
    check assertToken(KEY_VALUE_SEPARATOR, 2);
}

@test:Config {}
function testDot() returns error? {
    setLexerString("outer.'inner' = 3");
    check assertToken(UNQUOTED_KEY, lexeme = "outer");
    check assertToken(DOT);
    check assertToken(LITERAL_STRING, lexeme = "inner");
}