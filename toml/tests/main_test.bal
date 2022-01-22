import ballerina/test;

@test:Config{}
function testSimpleKey() returns error?{
    map<any> toml = check read("somekey = \"somevalue\"");

    test:assertTrue(toml.hasKey("somekey"));
    test:assertEquals(<string>toml["somekey"], "somevalue");
}

@test:Config {}
function testInvalidSimpleKey() {
    map<any>|error toml; 
    toml = read("somekey = somevalue");
    test:assertTrue(toml is ParsingError);

    toml = read("somekey = #somecomment");
    test:assertTrue(toml is ParsingError);

    toml = read("somekey somevalue");
    test:assertTrue(toml is ParsingError);
}

@test:Config {}
function testReadFromFile() returns error? {
    map<any> toml = check readFile("toml/tests/resources/simple_key.toml");

    test:assertTrue(toml.hasKey("simple-key"));
    test:assertEquals(<string>toml["simple-key"], "some-value");

    test:assertTrue(toml.hasKey("second-key"));
    test:assertEquals(<string>toml["second-key"], "second-value");
}