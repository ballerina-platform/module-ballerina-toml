# Holds state of the writer package.
#
# + output - The output lines to be written to the file
# + indent - Whitespace for an indent
# + allowDottedKeys - If flag is set, write dotted keys instead of standard tables.
type State record {|
    string[] output;
    readonly string indent;
    readonly boolean allowDottedKeys;
|};

# Write the TOML structure to the given file.
# Follows an extension of the BFS.
#
# + structure - TOML structure to be written  
# + indentationPolicy - Number of whitespace for an indent  
# + allowDottedKeys - If flag is set, write dotted keys instead of standard tables.
# + return - An error on failure
public function write(map<json> structure, int indentationPolicy, boolean allowDottedKeys) 
    returns string[]|WritingError {
    
    // Setup the indent whitespace
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

    // Remove the whitespace at the start of document if exists.
    if state.output[0].length() == 0 {
        _ = state.output.remove(0);
    }

    return state.output;
}
