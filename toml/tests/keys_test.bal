import ballerina/test;

@test:Config {}
function testFullLineComment() returns error? {
    Lexer lexer = setLexerString("# someComment");
    check assertToken(lexer, EOL);
}

@test:Config {}
function testEOLComment() returns error? {
    Lexer lexer = setLexerString("someKey = \"someValue\" # someComment");
    check assertToken(lexer, EOL, 7);
}

@test:Config {}
function testMultipleWhiteSpaces() returns error? {
    Lexer lexer = setLexerString("  ");
    check assertToken(lexer, WHITESPACE);
    check assertToken(lexer, EOL);
}

@test:Config {}
function testUnquotedKey() returns error? {
    Lexer lexer = setLexerString("somekey = \"Some Value\"");
    check assertToken(lexer, UNQUOTED_KEY, lexeme = "somekey");
}

@test:Config {}
function testUnquotedKeyWithInvalidChar() {
    Lexer lexer = setLexerString("some$value = 1");
    assertLexicalError(lexer);
}

@test:Config {}
function testKeyValueSeperator() returns error? {
    Lexer lexer = setLexerString("somekey = 1");
    check assertToken(lexer, WHITESPACE, 2);
    check assertToken(lexer, KEY_VALUE_SEPERATOR);
    check assertToken(lexer, WHITESPACE);
}

// Parsing Testing

@test:Config {}
function testSimpleUnquotedKey() returns error? {
    map<any> toml = check read("somekey = \"somevalue\"");

    test:assertTrue(toml.hasKey("somekey"));
    test:assertEquals(<string>toml["somekey"], "somevalue");
}

@test:Config {}
function testInvalidSimpleKey() {
    assertParsingError("somekey = somevalue");
    assertParsingError("somekey = #somecomment");
    assertParsingError("somekey somevalue");
}

@test:Config {}
function testReadFromFile() returns error? {
    map<any> toml = check readFile("toml/tests/resources/simple_key.toml");

    test:assertTrue(toml.hasKey("simple-key"));
    test:assertEquals(<string>toml["simple-key"], "some-value");

    test:assertTrue(toml.hasKey("second-key"));
    test:assertEquals(<string>toml["second-key"], "second-value");
}