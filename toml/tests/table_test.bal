import ballerina/test;

@test:Config {}
function testDoubleBracketTerminalTokens() returns error? {
    Lexer lexer = setLexerString("[[");
    check assertToken(lexer, DOUBLE_OPEN_BRACKET);

    lexer = setLexerString("]]");
    check assertToken(lexer, DOUBLE_CLOSE_BRACKET);
}