import ballerina/test;

@test:Config {}
function testValidQuotesWithNewlinesBasicMultilineString() returns error? {
    AssertKey ak = check new AssertKey("multi_quotes", true);
    ak.hasKey("str1", "single-quote\" \\ndouble-quotes\"\" \\nsingle-apastrophe' \\ndouble-appastrophe'' \\n").close();
}

@test:Config {}
function testMultilineEscapeWhitespaces() returns error? {
    AssertKey ak = check new AssertKey("str1 = \"\"\"escape\\  whitespace\"\"\"");
    ak.hasKey("str1", "escapewhitespace").close();
}

@test:Config {}
function testMultilineEscapeNewlines() returns error? {
    AssertKey ak = check new AssertKey("multi_escape", true);
    ak.hasKey("str1", "escapewhitespace").close();
}

@test:Config {}
function testDelimiterInsideMultilineBasicString() {
    assertParsingError("str1 = \"\"\"\"\"\"\"\"\"");
}

@test:Config {}
function testDelimiterInsideTheMultilinneLiteralString() {
    assertParsingError("str1 = '''''''''");
}

@test:Config {}
function testValidMultiLineLiteralString() returns error? {
    AssertKey ak = check new AssertKey("str = '''somevalue'''");
    ak.hasKey("str", "somevalue").close();
}

@test:Config {}
function testValidApostropheInMultilineLiteralString() returns error? {
    AssertKey ak = check new AssertKey("str = '''single'double'''''");
    ak.hasKey("str", "single'double''").close();
}

@test:Config {}
function testMultilineLiteralStrinsNewLines() returns error? {
    AssertKey ak = check new AssertKey("multi_literal", true);
    ak.hasKey("str1", "single' \\ndouble''\\n").close();
}
