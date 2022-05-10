import ballerina/test;

@test:Config {
    dataProvider: illegalUnderscoreDataGen
}
function testIllegalUnderscore(string testingLine) returns error? {
    assertParsingError(testingLine, isLexical = true);
}

function illegalUnderscoreDataGen() returns map<[string]> {
    return {
        "at start": ["flt = _1"],
        "at end": ["flt = 1_"]
    };
}

@test:Config {}
function testLeadingZeroDecimal() {
    assertParsingError("somekey = 012");
}

@test:Config {}
function testProcessDecimalValue() returns error? {
    AssertKey ak = check new AssertKey("somekey = 123");
    ak.hasKey("somekey", 123).close();
}
@test:Config {}
function testProcessBooleanValues() returns error? {
    AssertKey ak = check new AssertKey("somekey = true");
    ak.hasKey("somekey", true).close();
}

@test:Config {}
function testProcessFractionalNumbers() returns error? {
    AssertKey ak = check new AssertKey("float_fractional", true);
    ak.hasKey("flt1", 1.0).hasKey("flt2", 3.14).hasKey("flt3", -0.1).close();
}

@test:Config {}
function testPorcessExponentialNumbers() returns error? {
    AssertKey ak = check new AssertKey("float_exponential", true);
    ak  .hasKey("flt1", 500.0)
        .hasKey("flt2", -0.02)
        .hasKey("flt3", 0.0)
        .hasKey("flt4", 0.0)
        .hasKey("flt5", 0.0)
        .hasKey("flt6", 0.0)
        .close();
}


@test:Config {
    dataProvider: invalidDecimalPointDataGen
}
function testInvalidDecimalPoint(string testingLine) returns error? {
    assertParsingError(testingLine);
}

function invalidDecimalPointDataGen() returns map<[string]> {
    return {
        "at start": ["flt = .1"],
        "at end": ["flt = 1."],
        "before exponential": ["flt = 1."]
    };
}

@test:Config {}
function testFloatWithUnderscore() returns error? {
    AssertKey ak = check new AssertKey("flt = 123_456.123_456");
    ak.hasKey("flt", 123456.123456).close();
}

@test:Config {}
function testProcessBinaryNumbers() returns error? {
    AssertKey ak = check new AssertKey("bin = 0b0101");
    ak.hasKey("bin", 5).close();
}

@test:Config {}
function testProcessOctalNumbers() returns error? {
    AssertKey ak = check new AssertKey("bin = 0o0172");
    ak.hasKey("bin", 122).close();
}

@test:Config {}
function testProcessHexaDecimalNumbers() returns error? {
    AssertKey ak = check new AssertKey("bin = 0xab12");
    ak.hasKey("bin", 43794).close();
}

@test:Config {}
function testProcessInfinityValues() returns error? {
    AssertKey ak = check new AssertKey("infinity", true);
    ak.hasKey("sf1", 'float:Infinity)
        .hasKey("sf2", 'float:Infinity)
        .hasKey("sf3", -'float:Infinity)
        .close();
}

@test:Config {}
function testProcessNaNValues() returns error? {
    AssertKey ak = check new AssertKey("nan", true);
    ak.hasKey("sf1", 'float:NaN)
        .hasKey("sf2", 'float:NaN)
        .hasKey("sf3", 'float:NaN)
        .close();
}