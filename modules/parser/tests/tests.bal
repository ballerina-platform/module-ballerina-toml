import ballerina/test;
import ballerina/time;
import ballerina/io;

const ORIGIN_FILE_PATH = "modules/parser/tests/resources/";

# Parses a single line of a TOML string into a Ballerina map object.
#
# + tomlString - Single line of a TOML string
# + return - TOML map object is success. Else, returns an error
function readString(string tomlString) returns map<json>|error {
    string[] lines = [tomlString];
    return check parse(lines, true);
}

# Parses a TOML file into a Ballerina map object.
#
# + filePath - Path to the toml file
# + return - TOML map object is success. Else, returns an error
function read(string filePath) returns map<json>|error {
    string[] lines = check io:fileReadLines(filePath);
    return check parse(lines, true);
}

@test:Config {
    dataProvider: validTOMLDataGen,
    groups: ["parser"]
}
function testValidTOMLParse(string line, boolean isFile, json expectedOutput) returns error? {
    map<json> output = isFile
        ? <map<json>>(check read(ORIGIN_FILE_PATH + line + ".toml"))
        : <map<json>>(check readString(line));
    test:assertEquals(output, expectedOutput);
}

@test:Config {
    dataProvider: validODTDataGen,
    groups: ["parser"]
}
function testValidODTParse(string line, string timeString) returns error? {
    time:Utc expectedTime = check time:utcFromString(timeString);
    map<json> output = check readString(line);
    test:assertEquals(output, {odt: expectedTime});
}

@test:Config {
    dataProvider: invalidTOMLDataGen,
    groups: ["parser"]
}
function testInvalidTOMLParse(string line, boolean isFile) returns error? {
    map<json>|error toml = isFile ? read(ORIGIN_FILE_PATH + line + ".toml") : readString(line);
    test:assertTrue(toml is ParsingError);
}

@test:Config {
    groups: ["parser"]
}
function testAvoidParsingODT() returns error? {
    map<json> output = check parse(["odt = 1979-05-27T07:32:00Z"], false);
    test:assertEquals(output.odt, "1979-05-27T07:32:00Z");
}
