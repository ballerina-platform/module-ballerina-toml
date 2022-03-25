import ballerina/test;

@test:Config {}
function testDoubleBracketTerminalTokens() returns error? {
    setLexerString("[[");
    check assertToken(ARRAY_TABLE_OPEN);

    setLexerString("]]");
    check assertToken(ARRAY_TABLE_CLOSE);
}

@test:Config {}
function testInlineTableTerminalTokens() returns error? {
    setLexerString("{", EXPRESSION_VALUE);
    check assertToken(INLINE_TABLE_OPEN);

    setLexerString("}", EXPRESSION_VALUE);
    check assertToken(INLINE_TABLE_CLOSE);
}