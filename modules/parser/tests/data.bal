function validTOMLDataGen() returns map<[string, boolean, json]> {
    return {
        "simple unquoted key": ["somekey = \"somevalue\"", false, {somekey: "somevalue"}],
        "simple quoted basic string key": ["\"somekey\" = \"somevalue\"", false, {somekey: "somevalue"}],
        "simple quoted literal string key": ["'somekey' = \"somevalue\"", false, {somekey: "somevalue"}],
        "decimal value": ["somekey = 123", false, {somekey: 123}],
        "binary value": ["somekey = 0b0101", false, {somekey: 5}],
        "octal value": ["somekey = 0o0172", false, {somekey: 122}],
        "hexadecimal value": ["somekey = 0xab12", false, {somekey: 43794}],
        "boolean true": ["somekey = true", false, {somekey: true}],
        "boolean false": ["somekey = false", false, {somekey: false}],
        "basic float": ["somekey = 3.14", false, {somekey: <decimal>3.14}],
        "float with 0 after decimal": ["somekey = 1.0", false, {somekey: <decimal>1.0}],
        "negative float": ["somekey = -1.0", false, {somekey: <decimal>-1.0}],
        "float with underscore": ["somekey = 123_456.123_456", false, {somekey: <decimal>   123456.123456}],
        "unsigned infinity": ["somekey = inf", false, {somekey: float:Infinity}],
        "positive infinity": ["somekey = +inf", false, {somekey: float:Infinity}],
        "negative infinity": ["somekey = -inf", false, {somekey: -float:Infinity}],
        "unsigned NaN": ["somekey = nan", false, {somekey: float:NaN}],
        "positive NaN": ["somekey = +nan", false, {somekey: float:NaN}],
        "negative NaN": ["somekey = -nan", false, {somekey: float:NaN}],
        "zero float": ["somekey = 0.0", false, {somekey: <decimal>0}],
        "zero exponential float": ["somekey = 0e0", false, {somekey: <decimal>0}],
        "two zero exponential float": ["somekey = 0e00", false, {somekey: <decimal>0}],
        "positive float exponential": ["somekey = 5e+2", false, {somekey: <decimal>500.0}],
        "negative float exponential": ["somekey = -2E-2", false, {somekey: <decimal>-0.02}],
        "space as time delimiter": ["somekey = 1979-05-27 07:32:00", false, {somekey: "1979-05-27T07:32:00"}],
        "t as time delimiter": ["somekey = 1979-05-27t07:32:00", false, {somekey: "1979-05-27T07:32:00"}],
        "T as time delimiter": ["somekey = 1979-05-27T07:32:00", false, {somekey: "1979-05-27T07:32:00"}],
        "local date": ["somekey = 1922-12-12", false, {somekey: "1922-12-12"}],
        "local time": ["somekey = 07:32:00", false, {somekey: "07:32:00"}],
        "local time with fraction": ["somekey = 07:32:00.99", false, {somekey: "07:32:00.99"}],
        "multiple keys": ["simple_key", true, {"first-key": "first-value", "second-key": "second-value"}],
        "dotted keys": ["outer.inner = 'somevalue'", false, {"outer": {"inner": "somevalue"}}],
        "dotted keys with same outer": [
            "dotted_same_outer",
            true,
            {
                "outer2": "value2",
                "outer1": {
                    "inner1": "value1",
                    "inner2": {
                        "inner3": "value3",
                        "inner4": "value4"
                    },
                    "inner5": {
                        "inner3": "value5"
                    }
                }
            }
        ],
        "array ending with separator": ["arr = [1,2,]", false, {arr: [1, 2]}],
        "empty array": ["arr = []", false, {arr: []}],
        "array with different values": ["arr = [1, 's', true, [1, 2], 1.0]", false, {arr: [1, "s", true, [1, 2], <decimal>1.0]}],
        "array for multiple lines": ["array_multi", true, {arr: [1, "s", true, [1, 2], <decimal>1.0]}],
        "array of inline tables": ["array_inline_tables", true, {points: [{x: 1, y: 2}, {x: 3, y: 4}]}],
        "escape new liens in basic multiline string": ["multi_escape", true, {"str1": "escapewhitespace"}],
        "basic multiline basic string": ["str = \"\"\"somevalue\"\"\"", false, {"str": "somevalue"}],
        "basic multiline literal string": ["str = '''somevalue'''", false, {"str": "somevalue"}],
        "ignore first line of multiline": ["multi_ignore_first", true, {"str": "ignore first line"}],
        "apostrophe in multiline literal string": ["str = '''single'double'''''", false, {"str": "single'double''"}],
        "new lines in multiline literal string": ["multi_literal", true, {"str1": "single' \ndouble''\n"}],
        "escape whitespace in basic multiline string": [
            "str1 = \"\"\"escape\\  whitespace\"\"\"",
            false,
            {"str1": "escapewhitespace"}
        ],
        "valid quotes in basic multiline string": [
            "multi_quotes",
            true,
            {"str1": "single-quote\" \ndouble-quotes\"\" \nsingle-apastrophe' \ndouble-appastrophe'' \n"}
        ],
        "array table for same object": [
            "array_table_same_object",
            true,
            {
                "table": [
                    {key: 1, str: "a"},
                    {key: 2, str: "b"}
                ]
            }
        ],
        "array tables as sub tables": [
            "array_table_sub",
            true,
            {
                "a": [
                    {
                        "key1": 1,
                        "b": {"key2": 2},
                        "c": [
                            {"key3": 3}
                        ]
                    },
                    {
                        "key4": 4,
                        "c": [
                            {"key5": 5}
                        ]
                    }
                ]
            }
        ],
        "array tables repeated": [
            "array_table_repeated",
            true,
            {
                "table": [
                    {key1: 1, str1: "a"},
                    {},
                    {str2: "b", bool: false}
                ]
            }
        ],
        "multiple standard tables": [
            "table_standard",
            true,
            {
                "table1": {
                    "key1": 1,
                    "key2": "a"
                },
                "table2": {
                    "key1": 2,
                    "key2": "b"
                }
            }
        ],
        "dotted standard tables": [
            "table_dotted_keys",
            true,
            {
                "outer": {
                    "key": 1,
                    "inner": {
                        "key1": 1,
                        "key2": 2
                    }
                }
            }
        ],
        "table undefined dotted key": [
            "table_undefined_dotted",
            true,
            {
                "table": {
                    "outer": {
                        "key": 1,
                        "inner": 1
                    }
                }
            }
        ],
        "multiple inline tables": [
            "inline_table",
            true,
            {
                "animal": {
                    "type": {
                        "name": "pug"
                    }
                },
                "name": {
                    "first": "Tom",
                    "last": "Preston-Werner"
                },
                "point": {
                    "x": 1,
                    "y": 2
                }
            }
        ],
        "same key of different tables": [
            "table_same_key_diff_tables",
            true,
            {
                "a": {
                    "c": {
                        "d": 1
                    }
                },
                "b": {
                    "c": {
                        "d": 2
                    }
                }
            }
        ],
        "empty inline table": ["key = {}", false, {key: {}}]
    };
}

function validODTDataGen() returns map<[string, string]> {
    return {
        "default Zulu": ["odt = 1979-05-27T07:32:00Z", "1979-05-27T07:32:00Z"],
        "second fraction": ["odt = 1979-05-27T07:32:00.99Z", "1979-05-27T07:32:00.99Z"],
        "time difference": ["odt =  1979-05-27T00:32:00-07:00", "1979-05-27T07:32:00Z"],
        "time difference with fraction": ["odt =  1979-05-27T07:32:00.99+07:00", "1979-05-27T00:32:00.99Z"]
    };
}

function invalidTOMLDataGen() returns map<[string, boolean]> {
    return {
        "leading zero decimal": ["somekey = 012", false],
        "invalid decimal point at start": ["flt = .1"],
        "invalid decimal point at end": ["flt = 1."],
        "invalid decimal point before exponential": ["flt = 1.e0"],
        "illegal underscore at start": ["flt = _1"],
        "illegal underscore at end": ["flt = 1_"],
        "no delimiter in offset date time": ["odt = 1979-05-2707:32:00Z", false],
        "no offset in offset date time": ["odt = 1979-05-2707:32:00-", false],
        "invalid digits for year": ["ld = 192-12-12", false],
        "invalid digits for month": ["ld = 1922-2-12", false],
        "invalid digits for day": ["ld = 1922-02-2", false],
        "no year": ["ld = -02-01", false],
        "no month": ["ld = 1922-2-", false],
        "no day": ["ld = 1922-2-", false],
        "invalid digits for hours": ["ldt = 7:32:00", false],
        "invalid digits for minutes": ["ldt = 07:2:00", false],
        "invalid digits for seconds": ["ldt = 07:02:1", false],
        "no hours": ["ldt = :02:01", true],
        "no minutes": ["ldt = 07::01", false],
        "no seconds": ["ldt = 07:02:", false],
        "no fraction indicator": ["ldt = 07:32:0099", false],
        "bare keys as value": ["somekey = somevalue", false],
        "comment as value": ["somekey = #somecomment", false],
        "no equal sign": ["somekey somevalue", false],
        "no value": ["somekey =", false],
        "dotted already defined": ["dotted_already_defined", true],
        "dotted parent already defined": ["dotted_parent_already_defined", true],
        "multiple keys on one line": ["somekey1 = somevalue1 somekey2 = somevalue2", false],
        "duplicate keys": ["duplicate_keys", true],
        "subtable defined before array table": ["array_table_sub_before", true],
        "redefining static arrays by array tables": ["array_table_static", true],
        "array table redefines table": ["array_table_redefine_table", true],
        "unclosed array": ["arr = [1, 2", false],
        "delimiter inside multiline basic string": ["str1 = \"\"\"\"\"\"\"\"\"", false],
        "delimiter inside multiline literal string": ["str1 = '''''''''", false],
        "separator before }": ["key = {a=1,}", false],
        "separator before empty }": ["key = {,}", false],
        "duplicate table keys": ["table_duplicate", true],
        "redefining dotted keys": ["table_redefined_dotted", true],
        "redefining inline tables": ["inline_redefine_table", true],
        "redefining super table using inline table": ["inline_redefine_super_table", true],
        "redefining array table using standard table": ["table_redefine_array_table", true]
    };
}
