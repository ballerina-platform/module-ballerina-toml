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
