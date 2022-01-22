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