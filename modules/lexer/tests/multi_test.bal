import ballerina/test;

@test:Config {
    dataProvider: multilineTextDataGen
}
function testMutltilineString(string testLine, State testingState, TOMLToken expectedToken, int number, string expectedLexeme) returns error? {
    setLexerString(testLine, testingState);
    check assertToken(expectedToken, number, expectedLexeme);
}

function multilineTextDataGen() returns map<[string, State, TOMLToken, int, string]> {
    return {
        "escape": ["\"\"\"escape\\  whitespace\"\"\"", MULTILINE_BSTRING, MULTI_BSTRING_ESCAPE, 3, ""],
        "valid quotes": ["\"\"\"single-quote\"double-quotes\"\"single-apastrophe'double-appastrophe''\"\"\"", MULTILINE_BSTRING, MULTI_BSTRING_CHARS, 2, "single-quote\"double-quotes\"\"single-apastrophe'double-appastrophe''"],
        "literal": ["'''somevalue'''", MULITLINE_LSTRING, MULTI_LSTRING_CHARS, 2, "somevalue"],
        "literal delimiter": ["'''", EXPRESSION_VALUE, MULTI_LSTRING_DELIMITER, 0, ""],
        "basic": ["\"\"\"somevalue\"\"\"", MULTILINE_BSTRING, MULTI_BSTRING_CHARS, 2, "somevalue"],
        "basic delimiter": ["\"\"\"", EXPRESSION_VALUE, MULTI_BSTRING_DELIMITER, 0, ""]
    };
}
