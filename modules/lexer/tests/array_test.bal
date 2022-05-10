import ballerina/test;

@test:Config {
    dataProvider: arrayValueDataGen
}
function testArrayValue(string testingLine, TOMLToken expectedToken, int number, string expectedLexeme) returns error? {
    LexerState state = setLexerString(testingLine, EXPRESSION_VALUE);
    check assertToken(state, expectedToken, number);
}

function arrayValueDataGen() returns map<[string, TOMLToken, int, string]> {
    return {
        "starting array delimiter": ["[", OPEN_BRACKET, 0, ""],
        "ending array delimiter": ["]", CLOSE_BRACKET, 0, ""],
        "starting inline table delimiter": ["{", INLINE_TABLE_OPEN, 0, ""],
        "ending inline table delimiter": ["}", INLINE_TABLE_CLOSE, 0, ""],
        "same integers": ["[1, 2]", SEPARATOR, 3, ""],
        "string": ["[\"1\", 2]", SEPARATOR, 3, ""],
        "boolean": ["[true, 2]", SEPARATOR, 3, ""],
        "float": ["[1.0, 2]", SEPARATOR, 5, ""],
        "nested array": ["[[1], 2]", SEPARATOR, 5, ""]
    };
}
