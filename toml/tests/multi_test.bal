import ballerina/test;

@test:Config {}
function testMultiLineDelimiter() returns error? {
    Lexer lexer = setLexerString("\"\"\"");
    check assertToken(lexer, MULTI_STRING_DELIMETER);
}