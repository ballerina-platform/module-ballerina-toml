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

import toml.lexer;

# Process multi-line basic string.
#
# + state - Current parser state
# + return - An error if the grammar rule is not made  
isolated function multiBasicString(ParserState state) returns ParsingError|string {
    state.updateLexerContext(lexer:MULTILINE_BASIC_STRING);
    string lexemeBuffer = "";
    boolean isFirstLine = true;
    boolean isEscaped = false;
    boolean newLineInEscape = false;

    // Predict the next tokens
    check checkToken(state, [
        lexer:MULTILINE_BASIC_STRING_LINE,
        lexer:MULTILINE_BASIC_STRING_ESCAPE,
        lexer:MULTILINE_BASIC_STRING_DELIMITER,
        lexer:EOL
    ]);

    // Predicting the next tokens until the end of the string.
    while (state.currentToken.token != lexer:MULTILINE_BASIC_STRING_DELIMITER) {
        match state.currentToken.token {
            lexer:MULTILINE_BASIC_STRING_LINE => { // Regular basic string
                // When escaped, spaces are ignored and returns an empty string.
                if isEscaped {
                    // New lines has been detected while the escaped flag is on. Hence, a successful escape.
                    if newLineInEscape {
                        isEscaped = false;
                        newLineInEscape = false;
                    }
                    // Spaces are reduced to an empty string. If not, then a character is detected.
                    else if state.currentToken.value.length() != 0 {
                        return generateGrammarError(state, "Cannot escape whitespace in multiline basic string");
                    }
                }
                lexemeBuffer += state.currentToken.value;
            }
            lexer:MULTILINE_BASIC_STRING_ESCAPE => { // Escape token
                state.updateLexerContext(lexer:MULTILINE_ESCAPE);
                isEscaped = true;
            }
            lexer:EOL => { // Processing new lines
                check state.initLexer(generateGrammarError(state, "Expected to end the multi-line basic string"));

                // New lines are detected by the escaped
                if isEscaped {
                    newLineInEscape = true;
                }

                // Ignore new lines after the escape symbol
                if !(state.lexerState.context == lexer:MULTILINE_ESCAPE
                    || (isFirstLine && lexemeBuffer.length() == 0)) {
                    lexemeBuffer += "\n";
                }
                isFirstLine = false;
            }
        }
        check checkToken(state, [
            lexer:MULTILINE_BASIC_STRING_LINE,
            lexer:MULTILINE_BASIC_STRING_ESCAPE,
            lexer:MULTILINE_BASIC_STRING_DELIMITER,
            lexer:EOL
        ]);
    }

    // The escape does not work on whitespace without new lines.
    if isEscaped && !newLineInEscape {
        return generateGrammarError(state, "Cannot escape whitespace in multiline basic string");
    }

    state.updateLexerContext(lexer:EXPRESSION_KEY);
    return lexemeBuffer;
}

# Process multi-line literal string.
#
# + state - Current parser state
# + return - An error if the grammar production is not made.  
isolated function multiLiteralString(ParserState state) returns ParsingError|string {
    state.updateLexerContext(lexer:MULTILINE_LITERAL_STRING);
    string lexemeBuffer = "";
    boolean isFirstLine = true;

    // Predict the next tokens
    check checkToken(state, [
        lexer:MULTILINE_LITERAL_STRING_LINE,
        lexer:MULTILINE_LITERAL_STRING_DELIMITER,
        lexer:EOL
    ]);

    // Predicting the next tokens until the end of the string.
    while (state.currentToken.token != lexer:MULTILINE_LITERAL_STRING_DELIMITER) {
        match state.currentToken.token {
            lexer:MULTILINE_LITERAL_STRING_LINE => { // Regular literal string
                lexemeBuffer += state.currentToken.value;
            }
            lexer:EOL => { // Processing new lines    
                check state.initLexer(generateExpectError(state, lexer:MULTILINE_LITERAL_STRING_DELIMITER, lexer:MULTILINE_BASIC_STRING_DELIMITER));

                if !(isFirstLine && lexemeBuffer.length() == 0) {
                    lexemeBuffer += "\n";
                }
                isFirstLine = false;
            }
        }
        check checkToken(state, [
            lexer:MULTILINE_LITERAL_STRING_LINE,
            lexer:MULTILINE_LITERAL_STRING_DELIMITER,
            lexer:EOL
        ]);
    }

    state.updateLexerContext(lexer:EXPRESSION_KEY);
    return lexemeBuffer;
}
