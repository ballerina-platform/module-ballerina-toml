import toml.lexer;

# Assert the next lexer token with the predicted token.
# If no token is provided, then the next token is retrieved without an error checking.
# Hence, the error checking must be done explicitly.
#
# + state - Current parser state
# + expectedTokens - Predicted token or tokens
# + customMessage - Error message to be displayed if the expected token not found  
# + return - Parsing error if not found
function checkToken(ParserState state, lexer:TOMLToken|lexer:TOMLToken[] expectedTokens = lexer:DUMMY, string customMessage = "") returns ParsingError|lexer:LexicalError|() {
    lexer:TOMLToken prevToken = state.currentToken.token;
    state.lexerState = check lexer:scan(state.lexerState);
    state.currentToken = state.lexerState.getToken();

    // Bypass error handling.
    if (expectedTokens == lexer:DUMMY) {
        return;
    }

    // Automatically generates a template error message if there is no custom message.
    string errorMessage = customMessage.length() == 0
                                ? formatExpectErrorMessage(state.currentToken.token, expectedTokens, prevToken)
                                : customMessage;

    // Generate an error if the expected token differ from the actual token.
    if (expectedTokens is lexer:TOMLToken) {
        if (state.currentToken.token != expectedTokens) {
            return generateError(state, errorMessage);
        }
    } else {
        if (expectedTokens.indexOf(state.currentToken.token) == ()) {
            return generateError(state, errorMessage);
        }
    }

}

# Adds the current structure to the final TOML object.
#
# + state - Current parser state
# + structure - Structure to which the changes are made.
# + return - Constructed final toml object on success. Else, a parsing error.
function buildTOMLObject(ParserState state, map<json> structure) returns map<json>|ParsingError {
    // Under the root table
    if (state.keyStack.length() == 0) {
        return state.currentStructure;
    }

    // Under the key tables at the depth of 1
    if (state.keyStack.length() == 1) {
        string key = state.keyStack.pop();
        if (state.isArrayTable) {

            // Adds the current structure to the end of the array.
            if (structure[key] is json[]) {
                (<json[]>structure[key]).push(state.currentStructure.clone());

                // If the array does not exist, initialize and add it.
            } else {
                structure[key] = [state.currentStructure.clone()];
            }

            // If a standard table, assign the structure directly under the key
        } else {
            structure[key] = state.currentStructure;
        }
        return structure;
    }

    // Dotted tables
    string key = state.keyStack.shift();
    map<json> value;

    // If the key is a table
    if (structure[key] is map<json>) {
        value = check buildTOMLObject(state, <map<json>>structure[key]);
        structure[key] = value;
    }

        // If there is a standard table under an array table, obtain the latest object.
        else if (structure[key] is json[]) {
        value = check buildTOMLObject(state, <map<json>>(<json[]>structure[key]).pop());
        (<json[]>structure[key]).push(value);
    }

        // Creates a new structure if not exists.
        else {
        value = check buildTOMLObject(state, {});
        structure[key] = value;
    }

    return structure;
}

# Evaluates an integer of a different base
#
# + state - Current parser state
# + numberSystem - Number system of the value
# + return - Processed integer. Error if there is a string.
function processInteger(ParserState state, int numberSystem) returns int|ParsingError {
    int value = 0;
    int power = 1;
    int length = state.currentToken.value.length() - 1;
    foreach int i in 0 ... length {
        value += <int>(check processTypeCastingError(state, 'int:fromString(state.currentToken.value[length - i]))) * power;
        power *= numberSystem;
    }
    return value;
}

# Check errors during type casting to Ballerina types.
#
# + state - Current parser state
# + value - Value to be type casted.
# + return - Value as a Ballerina data type  
function processTypeCastingError(ParserState state, json|error value) returns json|ParsingError {
    // Check if the type casting has any errors
    if value is error {
        return generateError(state, "Invalid value for assignment");
    }

    // Returns the value on success
    return value;
}
