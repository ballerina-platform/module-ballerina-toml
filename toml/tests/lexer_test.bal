import ballerina/test;

@test:Config {}
function testFullLineComment() returns error? {
    Lexer lexer = setLexerString("# someComment");

    Token token = check lexer.getToken();
    test:assertEquals(token.token, EOL);

}

@test:Config {}
function testEOLComment() returns error? {
    Lexer lexer = setLexerString("someKey = \"someValue\" # someComment");
    Token token;

    foreach int i in 0 ... 6 {
        token = check lexer.getToken();
    }
    test:assertEquals(token.token, EOL);
}

@test:Config {}
function testMultipleWhiteSpaces() returns error? {
    Lexer lexer = setLexerString("  ");
    Token token;

    token = check lexer.getToken();
    test:assertEquals(token.token, WHITESPACE);

    token = check lexer.getToken();
    test:assertEquals(token.token, EOL);
}

@test:Config {}
function testUnquotedKey() returns error? {
    Lexer lexer = setLexerString("somekey = \"Some Value\"");

    Token token  = check lexer.getToken();
    test:assertEquals(token.token, BASIC_STRING);
    test:assertEquals(token.value, "somekey");
}

@test:Config {}
function testUnquotedKeyWithInvalidChar() {
    Lexer lexer = setLexerString("some$value = 1");

    Token|error token = lexer.getToken();
    test:assertTrue(token is LexicalError);
}

@test:Config {}
function testKeyValueSeperator() returns error? {
    Lexer lexer = setLexerString("somekey = 1");

    Token token1 = check lexer.getToken();
    test:assertEquals(token1.token, UNQUOTED_KEY);

    Token token2 = check lexer.getToken();
    test:assertEquals(token2.token, WHITESPACE);

    Token token3 = check lexer.getToken();
    test:assertEquals(token3.token, KEY_VALUE_SEPERATOR);
    
    Token token4 = check lexer.getToken();
    test:assertEquals(token4.token, WHITESPACE);
}

@test:Config {}
function testBasicString() returns error? {
    Lexer lexer = setLexerString("someKey = \"someValue\"");

    Token token1 = check lexer.getToken();
    test:assertEquals(token1.token, UNQUOTED_KEY);

    Token token2 = check lexer.getToken();
    test:assertEquals(token2.token, WHITESPACE);

    Token token3 = check lexer.getToken();
    test:assertEquals(token3.token, KEY_VALUE_SEPERATOR);
    
    Token token4 = check lexer.getToken();
    test:assertEquals(token4.token, WHITESPACE);

    Token token5 = check lexer.getToken();
    test:assertEquals(token5.token, BASIC_STRING);
    test:assertEquals(token5.value, "someValue");
}


# Returns a new lexer with the configured line for testing
#
# + line - Testing TOML string
# + return - Configured lexer  
function setLexerString(string line) returns Lexer {
    Lexer lexer = new Lexer();
    lexer.line = line;
    return lexer;
}