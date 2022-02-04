import ballerina/test;
import ballerina/file;

const dirPath = "writer";

@test:BeforeGroups {value: ["writer"]}
function initDirectory() returns error? {
    check file:createDir(dirPath);
}

@test:AfterGroups {value: ["writer"]}
function removeDirectory() returns error? {
    check file:remove(dirPath, file:RECURSIVE);
}

@test:Config {
    dataProvider: primitiveDateGen,
    groups: ["writer"]
}
function testPrimitiveValuesUnderCurrentKey(string key, anydata value, string expectedString) returns error? {
    string fileName = dirPath + "/primitive_values_" + key + ".toml";
    check file:create(fileName);
    map<anydata> toml = {
        key: value
    };
    check write(fileName, toml);
    check assertFile(fileName, expectedString);
    check file:remove(fileName);
}

function primitiveDateGen() returns map<[string, anydata, string]>|error {
    map<[string, anydata, string]> dataSet = {
        "int": ["int", 1, "int = 1"],
        "float": ["float", 1.01, "float = 1.01"],
        "boolean": ["boolean", true, "boolean = true"],
        "pos_inf": ["infinity", -'float:Infinity, "infinity = +inf"],
        "neg_inf": ["infinity", -'float:Infinity, "infinity = -inf"],
        "nan": ["NaN", 'float:NaN, "NaN = nan"]
    };
    return dataSet;
}
