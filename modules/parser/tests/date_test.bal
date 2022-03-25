import ballerina/test;
import ballerina/time;

@test:Config {}
function testODTZulu() returns error? {
    AssertKey ak = check new AssertKey("odt = 1979-05-27T07:32:00Z");
    ak.hasKey("odt", check time:utcFromString("1979-05-27T07:32:00Z")).close();
}

@test:Config {}
function testInvalidODT() {
    assertParsingError("odt = 1979-05-2707:32:00Z");
    assertParsingError("odt = 1979-05-27T07:32:00-");
}

@test:Config {}
function testODTTimeDifferenceOffset() returns error? {
    AssertKey ak = check new AssertKey("odt = 1979-05-27T00:32:00-07:00");
    ak.hasKey("odt", check time:utcFromString("1979-05-27T07:32:00Z")).close();
}

@test:Config {}
function testODTSecondFraction() returns error? {
    AssertKey ak = check new AssertKey("odt = 1979-05-27T07:32:00.99Z");
    ak.hasKey("odt", check time:utcFromString("1979-05-27T07:32:00.99Z")).close();
}

@test:Config {}
function testODTSecondFractionWithDifferenceOffset() returns error? {
    AssertKey ak = check new AssertKey("odt = 1979-05-27T07:32:00.99+07:00");
    ak.hasKey("odt", check time:utcFromString("1979-05-27T00:32:00.99Z")).close();
}

@test:Config {}
function testODTSupportDifferentTimeDelimiters() returns error? {
    AssertKey ak = check new AssertKey("date_time_delim", true);
    ak.hasKey("odt1", "1979-05-27T07:32:00")
        .hasKey("odt2", "1979-05-27T07:32:00")
        .hasKey("odt3", "1979-05-27T07:32:00")
        .close();
}

@test:Config {}
function testLocalDate() returns error? {
    AssertKey ak = check new AssertKey("ld = 1922-12-12");
    ak.hasKey("ld", "1922-12-12").close();
}

@test:Config {}
function testInvalidLocalDate() {
    assertParsingError("ld = 192-12-12");
    assertParsingError("ld = 1922-2-12");
    assertParsingError("ld = 1922-02-2");
    assertParsingError("ld = 1922-2-");
    assertParsingError("ld = 1922--1");
    assertParsingError("ld = -02-01");
}

@test:Config {}
function testLocalTime() returns error? {
    AssertKey ak = check new AssertKey("lt = 07:32:00");
    ak.hasKey("lt", "07:32:00").close();
}

@test:Config {}
function testLocalTimeWithFraction() returns error? {
    AssertKey ak = check new AssertKey("lt = 07:32:00.99");
    ak.hasKey("lt", "07:32:00.99").close();
}

@test:Config {}
function testInvalidLocalTime() {
    assertParsingError("ldt = 7:32:00");
    assertParsingError("ldt = 07:2:00");
    assertParsingError("ldt = 07:02:1");
    assertParsingError("ldt = :02:01", isLexical = true);
    assertParsingError("ldt = 07::01");
    assertParsingError("ldt = 07:02:");
    assertParsingError("ldt = 07:32:0099");
}

@test:Config {}
function testLocalDateTime() returns error? {
    AssertKey ak = check new AssertKey("ldt = 1979-05-27T07:32:00");
    ak.hasKey("ldt", "1979-05-27T07:32:00").close();
}
