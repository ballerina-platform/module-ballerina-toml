import ballerina/file;

# Holds state of the writer package.
#
# + output - The output lines to be written to the file
# + indent - Whitespace for an indent
# + allowDottedKeys - If flag is set, write dotted keys instead of standard tables.
type State record {|
    string[] output;
    string indent;
    boolean allowDottedKeys;
|};

# Write the TOML structure to the given file.
# Follows an extension of the BFS.
#
# + structure - TOML structure to be written  
# + indentationPolicy - Number of whitespace for an indent  
# + allowDottedKeys - If flag is set, write dotted keys instead of standard tables.
# + return - An error on failure
public function write(map<anydata> structure, int indentationPolicy, boolean allowDottedKeys) returns string[]|error {
    string indent = "";
    foreach int i in 1 ... indentationPolicy {
        indent += " ";
    }

    // Initialize the writer state
    State state = {
        output: [],
        indent,
        allowDottedKeys
    };

    check processStructure(state, structure, "", "");

    // Remove the start of document whitespace if exists.
    if (state.output[0].length() == 0) {
        _ = state.output.remove(0);
    }

    return state.output;
}

# Checks if the file exists. If not, creates a new file.
#
# + fileName - Path to the file
# + return - An error on failure
public function openFile(string fileName) returns error? {
    // Check if the given fileName is not directory
    if (check file:test(fileName, file:IS_DIR)) {
        return generateError("Cannot write to a directory");
    }

    // Create the file if the file does not exists
    if (!check file:test(fileName, file:EXISTS)) {
        check file:create(fileName);
    }
}
