import ballerina/io;
import ballerina/file;
import ballerina/test;

@test:Config {
    dataProvider: validTomlDataGen
}
function testValidTOML(string inputPath, json expectedOutput) returns error? {
    map<json> output = check read(inputPath, {parseOffsetDateTime: false});
    test:assertEquals(output, expectedOutput);
}

@test:Config {
    dataProvider: invalidTomlDataGen
}
function testInvalidTOML(string inputPath) {
    map<json>|error output = read(inputPath);
    test:assertTrue(output is error);
}

@test:Config {}
function testReadTOMLString() returns error? {
    map<json> output = check readString("key = 'value'");
    test:assertEquals(output, {"key": "value"});
}

@test:Config {}
function testWriteTOMLString() returns error? {
    string[] output = check writeString({"key": "value"});
    test:assertEquals(output[0], "key = \"value\"");
}

@test:Config {}
function testWriteTOMLFile() returns error? {
    check write("output.yml", {"outer": {"inner": "value"}}, allowDottedKeys = false, indentationPolicy = 4);
    string[] output = check io:fileReadLines("output.yml");
    test:assertEquals(output, ["[outer]", "inner = \"value\""]);
    check file:remove("output.yml");
}
