import ballerina/test;

@test:Config {}
function testBracketTerminalTokens() returns error? {
    setLexerString("[", EXPRESSION_VALUE);
    check assertToken(OPEN_BRACKET);

    setLexerString("]", EXPRESSION_VALUE);
    check assertToken(CLOSE_BRACKET);

}

@test:Config {}
function testArraySeparator() returns error? {
    setLexerString("[1, 2]", EXPRESSION_VALUE);
    check assertToken(SEPARATOR, 3);

    setLexerString("[\"1\", 2]", EXPRESSION_VALUE);
    check assertToken(SEPARATOR, 3);

    setLexerString("[true, 2]", EXPRESSION_VALUE);
    check assertToken(SEPARATOR, 3);

    setLexerString("[1.0, 2]", EXPRESSION_VALUE);
    check assertToken(SEPARATOR, 5);

    setLexerString("[[1], 2]", EXPRESSION_VALUE);
    check assertToken(SEPARATOR, 5);
}