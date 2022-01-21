import ballerina/test;

@test:Config {}
function testFullLineComment() returns error? {
    Lexer lexer = setLexerString("# someComment");

    Token token = check lexer.getToken();
    test:assertEquals(token.token, EOL);

}

@test:Config {}
function testEOLComment() returns error? {
    Lexer lexer = setLexerString("someKey = \"someKey\" # someComment");
    Token token;

    foreach int i in 0 ... 5 {
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
    test:assertEquals(token.token, UNQUOTED_KEY);
    test:assertEquals(token.value, "somekey");
}

@test:Config {}
function testUnquotedKeyWithInvalidChar() {
    Lexer lexer = setLexerString("key$aco = 21");

    Token|error token = lexer.getToken();
    test:assertTrue(token is LexicalError);
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