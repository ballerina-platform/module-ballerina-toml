import ballerina/test;
import ballerina/time;

@test:Config {
    dataProvider: primitiveDataGen,
    groups: ["writer"]
}
function testPrimitiveValuesUnderCurrentKey(string key, json value, string expectedString) returns error? {
    map<json> toml = {};
    toml[key] = value;
    check assertStringArray(toml, expectedString);
}

function primitiveDataGen() returns map<[string, json, string]>|error {
    return {
        "int": ["int", 1, "int = 1"],
        "str": ["str", "s", "str = \"s\""],
        "float": ["float", 1.01, "float = 1.01"],
        "boolean": ["boolean", true, "boolean = true"],
        "pos_inf": ["infinity", 'float:Infinity, "infinity = +inf"],
        "neg_inf": ["infinity", -'float:Infinity, "infinity = -inf"],
        "nan": ["NaN", 'float:NaN, "NaN = nan"],
        "utc": ["UTC", check time:utcFromString("1979-02-12T07:30:00Z"), "UTC = 1979-02-12T07:30:00Z"]
    };
}

@test:Config {
    dataProvider: validJsonDataGen
}
function testValidJsonWrite(map<json> toml, string[] output) returns error? {
    check assertStringArray(toml, output);
}

function validJsonDataGen() returns map<[map<json>, string[]]> {
    return {
        "simple dotted keys": [
            {
                "a": {
                    "b": 1
                }
            },
            ["a.b = 1"]
        ],
        "complex dotted keys": [
            {
                "a": {
                    "b": {
                        "c": {
                            "d": 1
                        }
                    }
                }
            },
            ["a.b.c.d = 1"]
        ],
        "inline arrays": [
            {
                "a": [
                    {"b": 1, "c": 2},
                    3
                ]
            },
            [
                "a = [",
                "  {\"b\":1,\"c\":2},",
                "  3,",
                "]"
            ]
        ],
        "array tables": [
            {
                "a": [
                    {"b": 1, "c": 2},
                    {"b": 2, "d": 3}
                ]
            },
            [
                "[[a]]",
                "b = 1",
                "c = 2",
                "",
                "[[a]]",
                "b = 2",
                "d = 3"
            ]
        ],
        "standard table under array table": [
            {
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
            },
            [
                "[[a]]",
                "b = 1",
                "c = 2",
                "",
                "[[a]]",
                "g = 5",
                "",
                "  [a.d]",
                "  e = 3",
                "  f = 4"
            ]
        ]
    };
}

@test:Config {}
function testInvalidNull() returns error? {
    string[]|WritingError key = write({"key": ()}, 2, true);
    test:assertTrue(key is WritingError);
}

# Assert if given word(s) are in the output array
#
# + structure - TOML structure to be tested  
# + content - Words to be which should be in the file  
# + disableOrder - Check if the output contains the lines in content without order
# + return - An error on fail
function assertStringArray(map<json> structure, string|string[] content,
    boolean disableOrder = false) returns error? {

    string[] output = check write(structure, 2, true);

    if content is string {
        test:assertTrue(output.indexOf(content) != ());
    } else {
        if disableOrder {
            test:assertTrue(content.reduce(function(boolean assertion, string word) returns boolean {
                return assertion && output.indexOf(word) != ();
            }, true));
        } else {
            test:assertEquals(output, content);
        }
    }
}
