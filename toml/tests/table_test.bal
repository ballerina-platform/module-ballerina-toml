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

@test:Config {}
function testDottedStandardTables() returns error? {
    AssertKey ak = check new AssertKey("table_dotted_keys",true);
    ak.hasKey("outer")
        .dive("outer")
            .hasKey("key", 1)
            .dive("inner")
                .hasKey("key1", 1)
                .close();
}

@test:Config {}
function testDuplicateTableKeys() {
    assertParsingError("table_duplicate", true);
}

@test:Config {}
function testRedefiningDottedKey() {
    assertParsingError("table_redefined_dotted", true);
}

@test:Config {}
function testTableUndefinedDottedKey() returns error? {
    AssertKey ak = check new AssertKey("table_undefined_dotted", true);
    ak.dive("table")
        .dive("outer")
            .hasKey("key", 1)
            .hasKey("inner", 1)
            .close();
}

@test:Config {}
function testInlineTableTerminalTokens() returns error? {
    Lexer lexer = setLexerString("{", EXPRESSION_VALUE);
    check assertToken(lexer, INLINE_TABLE_OPEN);

    lexer = setLexerString("}", EXPRESSION_VALUE);
    check assertToken(lexer, INLINE_TABLE_CLOSE);
}

@test:Config {}
function testProcesInlineTable() returns error? {
    AssertKey ak = check new AssertKey("inline_table", true);
    ak.dive("name")
        .hasKey("first", "Tom")
        .hop()
    .dive("point")
        .hasKey("x", 1)
        .hop()
    .dive("animal")
        .dive("type")
            .hasKey("name", "pug")
            .close();
}
@test:Config {}
function testRedefineInlineTable() {
    assertParsingError("inline_redefine_table", true);
}

@test:Config {}
function testEmptyInlineTable() returns error? {
    AssertKey ak = check new AssertKey("key = {}");
    ak.hasKey("key").close();
}

@test:Config {}
function testSeparatorBeforeInlineTableTerminal() {
    assertParsingError("key = {a=1,}");
    assertParsingError("{,}");
}