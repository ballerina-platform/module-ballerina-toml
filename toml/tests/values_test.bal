import ballerina/test;

@test:Config {}
function testBasicString() returns error? {
    Lexer lexer = setLexerString("someKey = \"someValue\"");
    check assertToken(lexer, BASIC_STRING, 3, "someValue");
}

@test:Config {}
function testLiteralString() returns error? {
    Lexer lexer = setLexerString("somekey = 'somevalue'");
    check assertToken(lexer, LITERAL_STRING, 3, "somevalue");
}