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

# Represents an error caused during the parsing.
public type ParsingError GrammarError|ConversionError|lexer:LexicalError;

# Represents an error caused for an invalid grammar production.
public type GrammarError distinct error<lexer:ReadErrorDetails>;

# Represents an error caused by the Ballerina lang when converting a data type.
public type ConversionError distinct error<lexer:ReadErrorDetails>;

# Generate an error message based on the template,
# "Expected ${expectedTokens} after ${beforeToken}, but found ${actualToken}"
#
# + state - Current parser state
# + expectedTokens - Expected tokens for the grammar production  
# + beforeToken - Token before the current one
# + return - Formatted error message
isolated function generateExpectError(ParserState state,
    lexer:TOMLToken|lexer:TOMLToken[]|string expectedTokens, lexer:TOMLToken beforeToken) returns GrammarError {

    string expectedTokensMessage;
    if expectedTokens is lexer:TOMLToken[] { // If multiple tokens
        string tempMessage = expectedTokens.reduce(isolated function(string message, lexer:TOMLToken token) returns string {
            return message + " '" + token + "' or";
        }, "");
        expectedTokensMessage = tempMessage.substring(0, tempMessage.length() - 3);
    } else { // If a single token
        expectedTokensMessage = " '" + <string>expectedTokens + "'";
    }
    string message =
        string `Expected${expectedTokensMessage} after '${beforeToken}', but found '${state.currentToken.token}'`;

    return generateGrammarError(state, message, expectedTokens);
}

# Generate an error message based on the template,
# "Duplicate key exists for ${value}"
#
# + state - Current parser state
# + value - Any value name. Commonly used to indicate keys.  
# + valueType - Possible types - key, table, value
# + return - Formatted error message
isolated function generateDuplicateError(ParserState state, string value, string valueType = "key") returns GrammarError
    => generateGrammarError(state, string `Duplicate ${valueType} exists for '${value}'`);

isolated function generateGrammarError(ParserState state, string message,
    json? expected = (), json? context = ()) returns GrammarError
        => error(
            message + ".",
            line = state.lexerState.row(),
            column = state.lexerState.column(),
            actual = state.currentToken.token,
            expected = expected
        );
