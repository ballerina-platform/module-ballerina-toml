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

@test:Config {
    groups: ["writer"]
}
function testWriteDottedKeys() returns error? {
    map<anydata> toml = {
        "a": {
            "b": 1
        }
    };
    check assertStringArray(toml, "a.b = 1");
}

@test:Config {
    groups: ["writer"]
}
function testWriteInlineArrays() returns error? {
    map<anydata> toml = {
        "a": [
            {"b": 1, "c": 2},
            3
        ]
    };
    check assertStringArray(toml, ["a = [", "]", "  {\"b\":1,\"c\":2},", "  3,"]);
}

@test:Config {
    groups: ["writer"]
}
function testWriteArrayTable() returns error? {
    map<anydata> toml = {
        "a": [
            {"b": 1, "c": 2},
            {"b": 2, "d": 3}
        ]
    };
    check assertStringArray(toml, ["[[a]]", "b = 1", "b = 2", "c = 2", "d = 3"]);
}

@test:Config {
    groups: ["writer"]
}
function testWriteStandardTableUnderArrayTable() returns error? {
    map<anydata> toml = {
        "a": [
            {"b": 1, "c": 2},
            {
                "d": {
                    "e": 3,
                    "f": 4
                },
                "g": 5
            }
        ]
    };
    check assertStringArray(toml, ["[[a]]", "b = 1", "c = 2", "  [a.d]", "  e = 3", "  f = 4", "g = 5"]);
}

# Assert if given word(s) are in the output array
#
# + structure - TOML structure to be tested
# + content - Words to be which should be in the file
# + return - An error on fail
function assertStringArray(map<anydata> structure, string|string[] content) returns error? {
    string[] output = check write(structure, 2, true);

    if (content is string) {
        test:assertTrue(output.indexOf(content) != ());
    } else {
        test:assertTrue(content.reduce(function(boolean assertion, string word) returns boolean {
            return assertion && output.indexOf(word) != ();
        }, true));
    }
}
