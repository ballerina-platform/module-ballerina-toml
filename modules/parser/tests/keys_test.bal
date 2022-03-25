import ballerina/test;

@test:Config {}
function testSimpleUnquotedKey() returns error? {
    AssertKey ak = check new AssertKey("somekey = \"somevalue\"");
    ak.hasKey("somekey", "somevalue").close();
}

@test:Config {}
function testSimpleQuotedBasicStringKey() returns error? {
    AssertKey ak = check new AssertKey("\"somekey\" = \"somevalue\"");
    ak.hasKey("somekey", "somevalue").close();
}

@test:Config {}
function testSimpleQuotedLiteralStringKey() returns error? {
    AssertKey ak = check new AssertKey("'somekey' = \"somevalue\"");
    ak.hasKey("somekey", "somevalue").close();
}

@test:Config {}
function testInvalidSimpleKey() {
    assertParsingError("somekey = somevalue", isLexical = true);
    assertParsingError("somekey = #somecomment");
    assertParsingError("somekey somevalue");
    assertParsingError("somekey =");
}

@test:Config {}
function testMultipleKeysOneLine() {
    assertParsingError("somekey1 = somevalue1 somekey2 = somevalue2", isLexical = true);
}

@test:Config {}
function testDuplicateKeys() {
    assertParsingError("duplicate_keys", true);
}

@test:Config {}
function testReadMultipleKeys() returns error? {
    AssertKey ak = check new AssertKey("simple_key", true);
    ak.hasKey("first-key", "first-value")
        .hasKey("second-key", "second-value")
        .close();
}

@test:Config {}
function testDottedKey() returns error? {
    AssertKey ak = check new AssertKey("outer.inner = 'somevalue'");
    ak.hasKey("outer")
        .dive("outer")
        .hasKey("inner", "somevalue")
        .close();
}

@test:Config {}
function testDottedKeyWithWhitespace() returns error? {
    AssertKey ak = check new AssertKey("outer . 'inner' = 'somevalue'");
    ak.hasKey("outer")
        .dive("outer")
        .hasKey("inner", "somevalue")
        .close();
}

@test:Config {}
function testDottedKeyWithSameOuter() returns error? {
    AssertKey ak = check new AssertKey("dotted_same_outer", true);
    ak.hasKey("outer1")
        .hasKey("outer2", "value2")
        .dive("outer1")
            .hasKey("inner1", "value1")
            .dive("inner2")
                .hasKey("inner3", "value3")
                .hasKey("inner4", "value4")
                .hop()
            .dive("inner5")
                .hasKey("inner3", "value5")
        .close();
}

@test:Config {}
function testDottedAlreadyDefined() {
    assertParsingError("dotted_already_defined", true);
}

@test:Config {}
function testDottedParentAlreadyDefined() {
    assertParsingError("dotted_parent_already_defined", true);
}
