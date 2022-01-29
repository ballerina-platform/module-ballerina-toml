import ballerina/test;

@test:Config {}
function testArrayTerimalTokens() returns error? {
    Lexer lexer = setLexerString("[", EXPRESSION_VALUE);
    check assertToken(lexer, ARRAY_START);

    lexer = setLexerString("]", EXPRESSION_VALUE);
    check assertToken(lexer, ARRAY_END);

}

@test:Config {}
function testArraySeparator() returns error? {
    Lexer lexer = setLexerString("[1, 2]", EXPRESSION_VALUE);
    check assertToken(lexer, ARRAY_SEPARATOR, 3);

    lexer = setLexerString("[\"1\", 2]", EXPRESSION_VALUE);
    check assertToken(lexer, ARRAY_SEPARATOR, 3);

    lexer = setLexerString("[true, 2]", EXPRESSION_VALUE);
    check assertToken(lexer, ARRAY_SEPARATOR, 3);

    lexer = setLexerString("[1.0, 2]", EXPRESSION_VALUE);
    check assertToken(lexer, ARRAY_SEPARATOR, 5);

    lexer = setLexerString("[[1], 2]", EXPRESSION_VALUE);
    check assertToken(lexer, ARRAY_SEPARATOR, 5);
}
