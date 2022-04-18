import ballerina/test;

@test:Config {
    dataProvider: multilineTextDataGen
}
function testMutltilineString(string testLine, Context testingState, TOMLToken expectedToken, int number, string expectedLexeme) returns error? {
    LexerState state = setLexerString(testLine, testingState);
    check assertToken(state, expectedToken, number, expectedLexeme);
}

function multilineTextDataGen() returns map<[string, Context, TOMLToken, int, string]> {
    return {
        "escape": ["\"\"\"escape\\  whitespace\"\"\"", MULTILINE_BASIC_STRING, MULTILINE_BASIC_STRING_ESCAPE, 3, ""],
        "valid quotes": ["\"\"\"single-quote\"double-quotes\"\"single-apastrophe'double-appastrophe''\"\"\"", MULTILINE_BASIC_STRING, MULTILINE_BASIC_STRING_LINE, 2, "single-quote\"double-quotes\"\"single-apastrophe'double-appastrophe''"],
        "literal": ["'''somevalue'''", MULTILINE_LITERAL_STRING, MULTILINE_LITERAL_STRING_LINE, 2, "somevalue"],
        "literal delimiter": ["'''", EXPRESSION_VALUE, MULTILINE_LITERAL_STRING_DELIMITER, 0, ""],
        "basic": ["\"\"\"somevalue\"\"\"", MULTILINE_BASIC_STRING, MULTILINE_BASIC_STRING_LINE, 2, "somevalue"],
        "basic delimiter": ["\"\"\"", EXPRESSION_VALUE, MULTILINE_BASIC_STRING_DELIMITER, 0, ""]
    };
}
