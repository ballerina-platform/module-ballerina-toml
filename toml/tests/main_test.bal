import ballerina/test;

@test:Config {}
function testSimpleKey() returns error? {
    map<any> toml = check read("somekey = \"somevalue\"");

    test:assertTrue(toml.hasKey("somekey"));
    test:assertEquals(<string>toml["somekey"], "somevalue");
}

@test:Config {}
function testInvalidSimpleKey() {
    assertParsingError("somekey = somevalue");
    assertParsingError("somekey = #somecomment");
    assertParsingError("somekey somevalue");
}

@test:Config {}
function testReadFromFile() returns error? {
    map<any> toml = check readFile("toml/tests/resources/simple_key.toml");

    test:assertTrue(toml.hasKey("simple-key"));
    test:assertEquals(<string>toml["simple-key"], "some-value");

    test:assertTrue(toml.hasKey("second-key"));
    test:assertEquals(<string>toml["second-key"], "second-value");
}

function assertKey(map<any> toml, string key, string value) {
    test:assertTrue(toml.hasKey(key));
    test:assertEquals(<string>toml[key], value);
}

# Assert if an parsing error is generated during the parsing
#
# + text - If isFile is set, file path else TOML string  
# + isFile - If set, reads the TOML file. default = false.  
function assertParsingError(string text, boolean isFile = false) {
    map<any>|error toml = isFile ? readFile(text) : read(text);
    test:assertTrue(toml is ParsingError);
}
