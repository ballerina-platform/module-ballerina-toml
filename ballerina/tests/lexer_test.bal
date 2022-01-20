import ballerina/test;

@test:Config {}
function testFullLineComment() {
    Lexer lexer = setLexerString("# someComment");

    Token token = lexer.getToken();
    test:assertEquals(token.token, COMMENT);

}

@test:Config {}
function testEOLComment() {
    Lexer lexer = setLexerString("someKey = \"someKey\" # someComment");
    Token token;

    foreach int i in 0...5 {
        token = lexer.getToken();
    }
    test:assertEquals(token.token, COMMENT);
}

@test:Config {}
function testMultipleWhiteSpaces() {
    Lexer lexer = setLexerString("  ");
    Token token;

    token = lexer.getToken();
    test:assertEquals(token.token, WHITE_SPACE);

    token = lexer.getToken();
    test:assertEquals(token.token, EOL);
}


# Returns a new lexer with the configured line for testing
#
# + line - Testing TOML string
# + return - Configured lexer  
function setLexerString(string line) returns Lexer{
    Lexer lexer = new Lexer();
    lexer.line = line;
    return lexer;
}