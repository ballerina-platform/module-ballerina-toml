# If the structure exists and already assigned a primitive value,
# then it is invalid to assign a value to it or nested to it.
#
# + structure - Parent key of the provided one 
# + key - Key to be verified in the structure  
# + return - Error, if there already exists a primitive value.
function verifyKey(ParserState state, map<json>? structure, string key) returns ParsingError? {
    if (structure is map<json>) {
        map<json> castedStructure = <map<json>>structure;
        if (castedStructure.hasKey(key) && !(castedStructure[key] is json[] || castedStructure[key] is map<json>)) {
            return generateError(state, "Duplicate values exists for '" + state.bufferedKey + "'");
        }
    }
}

# TOML allows only once to define a standard key table.
# This function checks if the table key name already exists.
#
# + tableKeyName - Table key name to be checked
# + return - An error if the key already exists.  
function verifyTableKey(ParserState state, string tableKeyName) returns ParsingError? {
    if (state.definedTableKeys.indexOf(tableKeyName) != ()) {
        return generateError(state, "Duplicate table key exists for '" + tableKeyName + "'");
    }
}

# Validates a given time component
#
# + value - Actual value in the TOML document 
# + lowerBound - Minimum acceptable value
# + upperBound - Maximum acceptable value
# + valueName - Name of the time component
# + return - Returns an error if the requirements are not met.
function checkTime(ParserState state, string value, int lowerBound, int upperBound, string valueName) returns ParsingError? {
    // Expected the time digits to be 2.
    if (value.length() != 2) {
        return generateError(state, "Expected number of digits in " + valueName + " to be 2");
    }
    int intValue = <int>check processTypeCastingError(state, 'int:fromString(value));
    if (intValue < lowerBound || intValue > upperBound) {
        return generateError(state, "Expected " + valueName + " to be between " + lowerBound.toString() + "-" + upperBound.toString());
    }
}

# Validates the date component.
#
# + value - Actual value in the TOML document  
# + numDigits - Required number of digits to the component. 
# + valueName - Name of the date component.
# + return - Returns the value in integer. Else, an parsing error.
function checkDate(ParserState state, string value, int numDigits, string valueName) returns int|ParsingError {
    if (value.length() != numDigits) {
        return generateError(state, "Expected number of digits in " + valueName + " to be " + numDigits.toString());
    }
    return <int>check processTypeCastingError(state, 'int:fromString(value));
}
