import ballerina/test;

@test:Config {}
function testBracketTerminalTokens() returns error? {
    Lexer lexer = setLexerString("[", EXPRESSION_VALUE);
    check assertToken(lexer, OPEN_BRACKET);

    lexer = setLexerString("]", EXPRESSION_VALUE);
    check assertToken(lexer, CLOSE_BRACKET);

}

@test:Config {}
function testArraySeparator() returns error? {
    Lexer lexer = setLexerString("[1, 2]", EXPRESSION_VALUE);
    check assertToken(lexer, SEPARATOR, 3);

    lexer = setLexerString("[\"1\", 2]", EXPRESSION_VALUE);
    check assertToken(lexer, SEPARATOR, 3);

    lexer = setLexerString("[true, 2]", EXPRESSION_VALUE);
    check assertToken(lexer, SEPARATOR, 3);

    lexer = setLexerString("[1.0, 2]", EXPRESSION_VALUE);
    check assertToken(lexer, SEPARATOR, 5);

    lexer = setLexerString("[[1], 2]", EXPRESSION_VALUE);
    check assertToken(lexer, SEPARATOR, 5);
}

@test:Config {}
function testArrayEndingWithSeparator() returns error? {
    AssertKey ak = check new AssertKey("arr = [1,2,]");
    ak.hasKey("arr", [1, 2]).close();
}

@test:Config {}
function testArrayWithDifferentValues() returns error? {
    AssertKey ak = check new AssertKey("arr = [1, 's', true, [1, 2], 1.0]");
    ak.hasKey("arr", [1, "s", true, [1, 2], 1.0]).close();
}

@test:Config {}
function testArrayForMultipleLines() returns error? {
    AssertKey ak = check new AssertKey("array_multi", true);
    ak.hasKey("arr", [1, "s", true, [1, 2], 1.0]).close();
}

@test:Config {}
function testUnclosedArray() {
    assertParsingError("arr = [1, 2");
}

@test:Config {}
function testEmptyArray() returns error? {
    AssertKey ak = check new AssertKey("arr = []");
    ak.hasKey("arr", []).close();
}

@test:Config {}
function testArrayOfInlineTables() returns error? {
    AssertKey ak = check new AssertKey("array_inline_tables", true);
    ak.hasKey("points", [{x: 1, y: 2}, {x: 3, y: 4}]).close();
}

@test:Config {}
function testArrayTableRepeated() returns error? {
    AssertKey ak = check new AssertKey("array_table_repeated", true);
    ak.hasKey("table", [
        {key1: 1, str1: "a"},
        {},
        {str2: "b", bool: false}
    ]).close();
}

@test:Config {}
function testArrayTableSubtables() returns error? {
    AssertKey ak = check new AssertKey("array_table_sub", true);
    ak.hasKey("a", [{
        "key1" : 1,
        "b" : {"key2": 2},
        "c" : [
            {"key3": 3}
        ]
    },{
        "key4" : 4,
        "c": [
            {"key5": 5}
        ]
    }]).close();
}

@test:Config {}
function testSubtableDefinedBeforeArrayTables() {
    assertParsingError("array_table_sub_before", true);
}

@test:Config {}
function testRedefiningStaticArraysByArrayTables() {
    assertParsingError("array_table_static", true);
}

@test:Config {}
function testArrayTableRedefineTable() {
    assertParsingError("array_table_redefine_table", true);
}

@test:Config {}
function testArrayTableForSameObject() returns error? {
    AssertKey ak = check new AssertKey("array_table_same_object", true);
    ak.hasKey("table", [
        {key: 1, str: "a"},
        {key: 2, str: "b"}
    ]).close();
}