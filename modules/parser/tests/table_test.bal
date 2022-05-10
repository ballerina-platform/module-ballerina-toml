import ballerina/test;

@test:Config {}
function testMultipleStandardTables() returns error? {
    AssertKey ak = check new AssertKey("table_standard", true);
    ak.hasKey("table1")
        .dive("table1")
            .hasKey("key1", 1)
            .hasKey("key2", "a")
            .hop()
        .dive("table2")
            .hasKey("key1", 2)
            .hasKey("key2", "b")
            .close();
}

@test:Config {}
function testDottedStandardTables() returns error? {
    AssertKey ak = check new AssertKey("table_dotted_keys", true);
    ak.hasKey("outer")
        .dive("outer")
            .hasKey("key", 1)
            .dive("inner")
                .hasKey("key1", 1)
                .close();
}

@test:Config {}
function testTableUndefinedDottedKey() returns error? {
    AssertKey ak = check new AssertKey("table_undefined_dotted", true);
    ak.dive("table")
        .dive("outer")
            .hasKey("key", 1)
            .hasKey("inner", 1)
            .close();
}

@test:Config {}
function testProcesInlineTable() returns error? {
    AssertKey ak = check new AssertKey("inline_table", true);
    ak.dive("name")
        .hasKey("first", "Tom")
        .hop()
    .dive("point")
        .hasKey("x", 1)
        .hop()
    .dive("animal")
        .dive("type")
            .hasKey("name", "pug")
            .close();
}

@test:Config {}
function testEmptyInlineTable() returns error? {
    AssertKey ak = check new AssertKey("key = {}");
    ak.hasKey("key").close();
}

@test:Config {}
function testSeparatorBeforeInlineTableTerminal() {
    assertParsingError("key = {a=1,}");
    assertParsingError("{,}");
}

@test:Config {
    dataProvider: invalidTableDataGen
}
function testInvalidTable(string fileName) returns error? {
    assertParsingError(fileName, true);
}

function invalidTableDataGen() returns map<[string]> {
    return {
        "duplicate table keys": ["table_duplicate"],
        "redefining dotted keys": ["table_redefined_dotted"],
        "redefining inline tables": ["inline_redefine_table"],
        "redefining super table using inline table": ["inline_redefine_super_table"],
        "redefining array table using standard table": ["table_redefine_array_table"]
    };
}

@test:Config {}
function testSameKeyOfDifferentTables() returns error? {
    AssertKey ak = check new AssertKey("table_same_key_diff_tables", true);
    ak.dive("a")
        .hasKey("c", {d: 1})
        .hop()
    .dive("b")
        .hasKey("c", {d: 2})
        .close();
}
