import toml.lexer;

# Assert the next lexer token with the predicted token.
# If no token is provided, then the next token is retrieved without an error checking.
# Hence, the error checking must be done explicitly.
#
# + expectedTokens - Predicted token or tokens
# + customMessage - Error message to be displayed if the expected token not found  
# + return - Parsing error if not found
function checkToken(lexer:TOMLToken|lexer:TOMLToken[] expectedTokens = lexer:DUMMY, string customMessage = "") returns ParsingError|lexer:LexicalError|() {
    lexer:TOMLToken prevToken = currentToken.token;
    currentToken = check lexer:scan();

    // Bypass error handling.
    if (expectedTokens == lexer:DUMMY) {
        return;
    }

    // Automatically generates a template error message if there is no custom message.
    string errorMessage = customMessage.length() == 0
                                ? check formatErrorMessage(1, expectedTokens, prevToken)
                                : customMessage;

    // Generate an error if the expected token differ from the actual token.
    if (expectedTokens is lexer:TOMLToken) {
        if (currentToken.token != expectedTokens) {
            return generateError(errorMessage);
        }
    } else {
        if (expectedTokens.indexOf(currentToken.token) == ()) {
            return generateError(errorMessage);
        }
    }

}

# Adds the current structure to the final TOML object.
#
# + structure - Structure to which the changes are made.
# + return - Constructed final toml object on success. Else, a parsing error.
function buildTOMLObject(map<json> structure) returns map<json>|ParsingError {
    // Under the root table
    if (keyStack.length() == 0) {
        return currentStructure;
    }

    // Under the key tables at the depth of 1
    if (keyStack.length() == 1) {
        string key = keyStack.pop();
        if (isArrayTable) {

            // Adds the current structure to the end of the array.
            if (structure[key] is json[]) {
                (<json[]>structure[key]).push(currentStructure.clone());

                // If the array does not exist, initialize and add it.
            } else {
                structure[key] = [currentStructure.clone()];
            }

            // If a standard table, assign the structure directly under the key
        } else {
            structure[key] = currentStructure;
        }
        return structure;
    }

    // Dotted tables
    string key = keyStack.shift();
    map<json> value;

    // If the key is a table
    if (structure[key] is map<json>) {
        value = check buildTOMLObject(<map<json>>structure[key]);
        structure[key] = value;
    }

        // If there is a standard table under an array table, obtain the latest object.
        else if (structure[key] is json[]) {
        value = check buildTOMLObject(<map<json>>(<json[]>structure[key]).pop());
        (<json[]>structure[key]).push(value);
    }

        // Creates a new structure if not exists.
        else {
        value = check buildTOMLObject({});
        structure[key] = value;
    }

    return structure;
}

# Evaluates an integer of a different base
#
# + numberSystem - Number system of the value
# + return - Processed integer. Error if there is a string.
function processInteger(int numberSystem) returns int|ParsingError {
    int value = 0;
    int power = 1;
    int length = currentToken.value.length() - 1;
    foreach int i in 0 ... length {
        value += <int>(check processTypeCastingError('int:fromString(currentToken.value[length - i]))) * power;
        power *= numberSystem;
    }
    return value;
}

# Check errors during type casting to Ballerina types.
#
# + value - Value to be type casted.
# + return - Value as a Ballerina data type  
function processTypeCastingError(json|error value) returns json|ParsingError {
    // Check if the type casting has any errors
    if value is error {
        return generateError("Invalid value for assignment");
    }

    // Returns the value on success
    return value;
}

# Initialize the lexer with the attributes of a new line.
#
# + message - Error message to display when if the initialization fails 
# + incrementLine - Sets the next line to the lexer
# + return - An error if it fails to initialize  
function initLexer(string message, boolean incrementLine = true) returns ParsingError? {
    if (incrementLine) {
        lineIndex += 1;
    }
    if (lineIndex >= numLines) {
        return generateError(message);
    }
    lexer:line = lines[lineIndex];
    lexer:index = 0;
    lexer:lineNumber = lineIndex;
}
