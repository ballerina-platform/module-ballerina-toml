import ballerina/test;

@test:Config {}
function testDoubleBracketTerminalTokens() returns error? {
    Lexer lexer = setLexerString("[[");
    check assertToken(lexer, DOUBLE_OPEN_BRACKET);

    lexer = setLexerString("]]");
    check assertToken(lexer, DOUBLE_CLOSE_BRACKET);
}

@test:Config {}
function testMultipleStandardTables() returns error? {
    AssertKey ak = check new AssertKey("table_standard", true);
    ak.hasKey("table1")
        .dive("table1")
            .hasKey("key1", 1)
            .hasKey("key2", "a")
            .hop()
        .dive("table2")
            .hasKey("key1", 2)
            .hasKey("key2", "b")
            .close();
}