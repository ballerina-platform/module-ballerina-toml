// Copyright (c) 2022, WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import ballerina/test;

@test:Config {
    groups: ["lexer"]
}
function testFullLineComment() returns error? {
    LexerState state = setLexerString("# someComment");
    check assertToken(state, EOL);
}

@test:Config {
    groups: ["lexer"]
}
function testEOLComment() returns error? {
    LexerState state = setLexerString("\"someValue\" # someComment", EXPRESSION_VALUE);
    check assertToken(state, EOL, 2);
}

@test:Config {
    groups: ["lexer"]
}
function testMultipleWhiteSpaces() returns error? {
    LexerState state = setLexerString("  ");
    check assertToken(state, EOL);
}

@test:Config {
    groups: ["lexer"]
}
function testscanUnquotedKey() returns error? {
    LexerState state = setLexerString("somekey = \"Some Value\"");
    check assertToken(state, UNQUOTED_KEY, lexeme = "somekey");
}

@test:Config {
    groups: ["lexer"]
}
function testscanUnquotedKeyWithInvalidChar() {
    assertLexicalError("some$value = 1");
}

@test:Config {
    groups: ["lexer"]
}
function testKeyValueSeparator() returns error? {
    LexerState state = setLexerString("somekey = 1");
    check assertToken(state, KEY_VALUE_SEPARATOR, 2);
}

@test:Config {
    groups: ["lexer"]
}
function testDot() returns error? {
    LexerState state = setLexerString("outer.'inner' = 3");
    check assertToken(state, UNQUOTED_KEY, lexeme = "outer");
    check assertToken(state, DOT);
    check assertToken(state, LITERAL_STRING, lexeme = "inner");
}

@test:Config {
    dataProvider: tableDelimiterDataGen,
    groups: ["lexer"]
}
function testTableDelimiterToken(string testingLine, TOMLToken expectedToken) returns error? {
    LexerState state = setLexerString(testingLine);
    check assertToken(state, expectedToken);
}

function tableDelimiterDataGen() returns map<[string, TOMLToken]> {
    return {
        "starting array table token": ["[[", ARRAY_TABLE_OPEN],
        "closing array table token": ["]]", ARRAY_TABLE_CLOSE],
        "starting table token": ["[", OPEN_BRACKET],
        "closing table token": ["]", CLOSE_BRACKET]
    };
}

