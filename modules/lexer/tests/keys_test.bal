import ballerina/test;

@test:Config {}
function testFullLineComment() returns error? {
    LexerState state = setLexerString("# someComment");
    check assertToken(state,EOL);
}

@test:Config {}
function testEOLComment() returns error? {
    LexerState state = setLexerString("someKey = \"someValue\" # someComment");
    check assertToken(state,EOL, 4);
}

@test:Config {}
function testMultipleWhiteSpaces() returns error? {
    LexerState state = setLexerString("  ");
    check assertToken(state,EOL);
}

@test:Config {}
function testUnquotedKey() returns error? {
    LexerState state = setLexerString("somekey = \"Some Value\"");
    check assertToken(state,UNQUOTED_KEY, lexeme = "somekey");
}

@test:Config {}
function testUnquotedKeyWithInvalidChar() {
    assertLexicalError("some$value = 1");
}

@test:Config {}
function testKeyValueSeparator() returns error? {
    LexerState state = setLexerString("somekey = 1");
    check assertToken(state,KEY_VALUE_SEPARATOR, 2);
}

@test:Config {}
function testDot() returns error? {
    LexerState state = setLexerString("outer.'inner' = 3");
    check assertToken(state,UNQUOTED_KEY, lexeme = "outer");
    check assertToken(state,DOT);
    check assertToken(state,LITERAL_STRING, lexeme = "inner");
}