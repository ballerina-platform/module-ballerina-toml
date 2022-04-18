import toml.lexer;

# Generates a map object for the TOML document.
# Considers the predictions for the 'expression', 'table', and 'array table'.
#
# + inputLines - TOML lines to be parsed.
# + return - If success, map object for the TOML document.
# Else, a lexical or a parsing error.
public function parse(string[] inputLines) returns map<json>|lexer:LexicalError|ParsingError {
    // Initialize the state 
    ParserState state = new (inputLines);

    // Iterating each line of the document.
    while state.lineIndex < state.numLines - 1 {
        check state.initLexer("Cannot open the TOML document");
        state.updateLexerContext(lexer:EXPRESSION_KEY);
        check checkToken(state);

        match state.currentToken.token {
            lexer:UNQUOTED_KEY|lexer:BASIC_STRING|lexer:LITERAL_STRING => { // Process a key value
                state.bufferedKey = state.currentToken.value;
                state.currentStructure = check keyValue(state, state.currentStructure.clone());
            }
            lexer:OPEN_BRACKET => { // Process a standard tale.
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

                check checkToken(state, [lexer:UNQUOTED_KEY, lexer:BASIC_STRING, lexer:LITERAL_STRING]);
                check arrayTable(state, state.tomlObject.clone());
            }
        }

        // Comments and new lines are ignored.
        // Other expressions cannot have additional tokens in their line.
        if (state.currentToken.token != lexer:EOL) {
            check checkToken(state, lexer:EOL);
        }
    }

    // Return the TOML object
    return buildTOMLObject(state, state.tomlObject.clone());
}
