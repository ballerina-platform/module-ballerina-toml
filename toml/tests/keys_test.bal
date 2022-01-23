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
function testSimpleQuotedBasicStringKey() returns error? {
    map<any> toml = check read("\"somekey\" = \"somevalue\"");

    test:assertTrue(toml.hasKey("somekey"));
    test:assertEquals(<string>toml["somekey"], "somevalue");
}

@test:Config {}
function testSimpleQuotedLiteralStringKey() returns error? {
    map<any> toml = check read("'somekey' = \"somevalue\"");

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
function testDuplicateKeys() {
    assertParsingError("duplicate_keys", true);
}

@test:Config {}
function testReadMultipleKeys() returns error? {
    AssertKey ak = check new AssertKey("simple_key", true);
    ak  .hasKey("first-key", "first-value")
        .hasKey("second-key", "second-value")
        .close();
}