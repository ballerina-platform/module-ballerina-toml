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

# Generates a map object for the TOML document.
# Considers the predictions for the 'expression', 'table', and 'array table'.
#
# + inputLines - TOML lines to be parsed.  
# + parseOffsetDateTime - Converts ODT to Ballerina time:Utc
# + return - Map object of the TOML document on success. Else, an parsing error.
public isolated function parse(string[] inputLines, boolean parseOffsetDateTime) returns map<json>|ParsingError {
    
    // Initialize the state 
    ParserState state = new (inputLines, parseOffsetDateTime);

    // Iterating each line of the document
    while state.lineIndex < state.numLines - 1 {
        check state.initLexer(generateGrammarError(state, "Cannot open the TOML document"));
        check checkToken(state);

        match state.currentToken.token {
            lexer:UNQUOTED_KEY|lexer:BASIC_STRING|lexer:LITERAL_STRING => { // Process a key value
                state.bufferedKey = state.currentToken.value;
                state.currentStructure = check keyValue(state, state.currentStructure.clone());
            }
            lexer:OPEN_BRACKET => { // Process a standard table
                // Add the previous table to the TOML object
                state.tomlObject = check buildTOMLObject(state, state.tomlObject.clone());
                state.isArrayTable = false;

                check checkToken(state, [lexer:UNQUOTED_KEY, lexer:BASIC_STRING, lexer:LITERAL_STRING]);
                check standardTable(state, state.tomlObject.clone());
            }
            lexer:ARRAY_TABLE_OPEN => { // Process an array table
                // Add the previous structure to the array in the TOML object.
                state.tomlObject = check buildTOMLObject(state, state.tomlObject.clone());
                state.isArrayTable = true;
                state.tempTableKeys = [];

                check checkToken(state, [lexer:UNQUOTED_KEY, lexer:BASIC_STRING, lexer:LITERAL_STRING]);
                check arrayTable(state, state.tomlObject.clone());
            }
        }
        state.updateLexerContext(lexer:EXPRESSION_KEY);

        // Comments and new lines are ignored.
        // Other expressions cannot have additional tokens in their line.
        if state.currentToken.token != lexer:EOL {
            check checkToken(state, lexer:EOL);
        }
    }

    // Return the TOML object
    return buildTOMLObject(state, state.tomlObject.clone());
}
