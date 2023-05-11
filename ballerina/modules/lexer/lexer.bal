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

public enum Context {
    EXPRESSION_KEY,
    EXPRESSION_VALUE,
    DATE_TIME,
    MULTILINE_BASIC_STRING,
    MULTILINE_LITERAL_STRING,
    MULTILINE_ESCAPE
}

final readonly & map<string> escapedCharMap = {
    "b": "\u{08}",
    "t": "\t",
    "n": "\n",
    "f": "\u{0c}",
    "r": "\r",
    "\"": "\"",
    "\\": "\\"
};

# Generates a Token for the next immediate lexeme.
#
# + state - The lexer state for the next token
# + return - If success, returns a token, else returns a Lexical Error
public isolated function scan(LexerState state) returns LexerState|LexicalError {

    // Generate EOL token 
    if state.peek() == () {
        return state.tokenize(EOL);
    }

    match state.context {
        EXPRESSION_KEY => {
            return contextExpressionKey(state);
        }
        EXPRESSION_VALUE => {
            return contextExpressionValue(state);
        }
        MULTILINE_BASIC_STRING|MULTILINE_ESCAPE => {
            return contextMultilineBasicString(state);
        }
        MULTILINE_LITERAL_STRING => {
            return contextMultilineLiteralString(state);
        }
        DATE_TIME => {
            return contextDateTime(state);
        }
    }

    return generateLexicalError(state, string `Invalid TOML context'`);
}
