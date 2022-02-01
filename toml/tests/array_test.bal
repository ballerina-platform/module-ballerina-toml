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
