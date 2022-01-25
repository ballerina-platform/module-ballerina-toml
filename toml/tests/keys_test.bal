import ballerina/test;

@test:Config {}
function testFullLineComment() returns error? {
    Lexer lexer = setLexerString("# someComment");
    check assertToken(lexer, EOL);
}

@test:Config {}
function testEOLComment() returns error? {
    Lexer lexer = setLexerString("someKey = \"someValue\" # someComment");
    check assertToken(lexer, EOL, 4);
}

@test:Config {}
function testMultipleWhiteSpaces() returns error? {
    Lexer lexer = setLexerString("  ");
    check assertToken(lexer, EOL);
}

@test:Config {}
function testUnquotedKey() returns error? {
    Lexer lexer = setLexerString("somekey = \"Some Value\"");
    check assertToken(lexer, UNQUOTED_KEY, lexeme = "somekey");
}

@test:Config {}
function testUnquotedKeyWithInvalidChar() {
    assertLexicalError("some$value = 1");
}

@test:Config {}
function testKeyValueSeperator() returns error? {
    Lexer lexer = setLexerString("somekey = 1");
    check assertToken(lexer, KEY_VALUE_SEPERATOR, 2);
}

@test:Config {}
function testDot() returns error? {
    Lexer lexer = setLexerString("outer.'inner' = 3");
    check assertToken(lexer, UNQUOTED_KEY, lexeme = "outer");
    check assertToken(lexer, DOT);
    check assertToken(lexer, LITERAL_STRING, lexeme = "inner");
}

// Parsing Testing

@test:Config {}
function testSimpleUnquotedKey() returns error? {
    AssertKey ak = check new AssertKey("somekey = \"somevalue\"");
    ak.hasKey("somekey", "somevalue").close();
}

@test:Config {}
function testSimpleQuotedBasicStringKey() returns error? {
    AssertKey ak = check new AssertKey("\"somekey\" = \"somevalue\"");
    ak.hasKey("somekey", "somevalue").close();
}

@test:Config {}
function testSimpleQuotedLiteralStringKey() returns error? {
    AssertKey ak = check new AssertKey("'somekey' = \"somevalue\"");
    ak.hasKey("somekey", "somevalue").close();
}

@test:Config {}
function testInvalidSimpleKey() {
    assertParsingError("somekey = somevalue", isLexical = true);
    assertParsingError("somekey = #somecomment");
    assertParsingError("somekey somevalue");
    assertParsingError("somekey =");
}

@test:Config {}
function testMultipleKeysOneLine() {
    assertLexicalError("somekey1 = somevalue1 somekey2 = somevalue2");
}

@test:Config {}
function testDuplicateKeys() {
    assertParsingError("duplicate_keys", true);
}

@test:Config {}
function testReadMultipleKeys() returns error? {
    AssertKey ak = check new AssertKey("simple_key", true);
    ak.hasKey("first-key", "first-value")
        .hasKey("second-key", "second-value")
        .close();
}

@test:Config {}
function testDottedKey() returns error? {
    AssertKey ak = check new AssertKey("outer.inner = 'somevalue'");
    ak.hasKey("outer")
        .dive("outer")
        .hasKey("inner", "somevalue")
        .close();
}

@test:Config {}
function testDottedKeyWithWhitespace() returns error? {
    AssertKey ak = check new AssertKey("outer . 'inner' = 'somevalue'");
    ak.hasKey("outer")
        .dive("outer")
        .hasKey("inner", "somevalue")
        .close();
}

@test:Config {}
function testDottedKeyWithSameOuter() returns error? {
    AssertKey ak = check new AssertKey("dotted_same_outer", true);
    ak.hasKey("outer1")
        .hasKey("outer2", "value2")
        .dive("outer1")
            .hasKey("inner1", "value1")
            .dive("inner2")
                .hasKey("inner3", "value3")
                .hasKey("inner4", "value4")
                .hop()
            .dive("inner5")
                .hasKey("inner3", "value5")
        .close();
}

@test:Config {}
function testDottedAlreadyDefined() {
    assertParsingError("dotted_already_defined", true);
}

@test:Config {}
function testDottedParentAlreadyDefined() {
    assertParsingError("dotted_parent_already_defined", true);
}
