import ballerina/test;
import ballerina/time;

@test:Config {
    dataProvider: primitiveDataGen,
    groups: ["writer"]
}
function testPrimitiveValuesUnderCurrentKey(string key, anydata value, string expectedString) returns error? {
    map<anydata> toml = {};
    toml[key] = value;
    check assertStringArray(toml, expectedString);
}

function primitiveDataGen() returns map<[string, anydata, string]>|error {
    map<[string, anydata, string]> dataSet = {
        "int": ["int", 1, "int = 1"],
        "str": ["str", "s", "str = \"s\""],
        "float": ["float", 1.01, "float = 1.01"],
        "boolean": ["boolean", true, "boolean = true"],
        "pos_inf": ["infinity", 'float:Infinity, "infinity = +inf"],
        "neg_inf": ["infinity", -'float:Infinity, "infinity = -inf"],
        "nan": ["NaN", 'float:NaN, "NaN = nan"],
        "utc": ["UTC", check time:utcFromString("1979-02-12T07:30:00Z"), "UTC = 1979-02-12T07:30:00Z"]
    };
    return dataSet;
}
