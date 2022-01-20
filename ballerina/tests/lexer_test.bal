import ballerina/test;

@test:Config {}
function testFullLineComment() {
    Lexer lexer = new Lexer();

    lexer.line = "# someComment";
    Token token = lexer.getToken();
    test:assertEquals(token.token, COMMENT);

}

@test:Config {}
function testEOLComment() {
    Lexer lexer = new Lexer();

    lexer.line = "someKey = \"someKey\" # someComment";
    Token token;
    foreach int i in 0...5 {
        token = lexer.getToken();
    }
    test:assertEquals(token.token, COMMENT);
}
