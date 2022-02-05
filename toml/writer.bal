import ballerina/file;
import ballerina/time;

# Represents an error caused by parser
type WritingError distinct error;

# Handles the process of writing the TOML structure to a file.
class Writer {

    # TOML lines to be written
    private string[] output = [];

    # Whitespaces for an indent
    private string indent = "";

    function init(int indentationPolicy = 2) {
        // Initialize the indent space
        foreach int i in 1 ... indentationPolicy {
            self.indent += " ";
        }
    }

    # Write the TOML structure to the given file.
    # Follows an extension of the BFS.
    #
    # + structure - TOML structure to be written
    # + return - An error on failure
    public function write(map<anydata> structure) returns string[]|error {
        check self.processStructure(structure, "", "");

        // Remove the start of document whitespace if exists.
        if (self.output[0].length() == 0) {
            _ = self.output.remove(0);
        }

        return self.output;
    }

    # Checks if the file exists. If not, creates a new file.
    #
    # + fileName - Path to the file
    # + return - An error on failure
    public function openFile(string fileName) returns error? {
        // Check if the given fileName is not directory
        if (check file:test(fileName, file:IS_DIR)) {
            return self.generateError("Cannot write to a directory");
        }

        // Create the file if the file does not exists
        if (!check file:test(fileName, file:EXISTS)) {
            check file:create(fileName);
        }
    }

    # Constructs the key value pairs for the current table
    #
    # + structure - Current table
    # + tableKey - Current table key
    # + whitespace - Indentation for the current table
    # + return - An error on failure
    private function processStructure(map<anydata> structure, string tableKey, string whitespace) returns error? {
        string[] keys = structure.keys();

        // List of array tables to be created
        [string, anydata[]][] arrayTables = [];

        // List of standard tables to be created
        [string, map<anydata>][] standardTables = [];

        // Traverse all the keys .
        foreach string key in keys {
            anydata value = structure[key];

            // This structure should be processed at the end of this depth level.
            // Builds both dotted keys or standard tables.
            if (value is map<anydata>) {
                check self.processTable(value, self.constructTableKey(tableKey, key), standardTables, whitespace);
                continue;
            }

            // Procss UTC time
            if (value is time:Utc) {
                self.output.push(whitespace + key + " = " + time:utcToString(<time:Utc>value));
                continue;
            }

            // This structure should be processed at the end of this depth level.
            // Builds both inline arrays or array tables.
            if (value is anydata[]) {
                check self.processArray(key, value, tableKey, arrayTables, whitespace);
                continue;
            }

            self.output.push(whitespace + key + " = " + check self.processPrimitiveValue(value));
        }

        // Construct the array tables
        if (arrayTables.length() > 0) {
            string newWhitespace = tableKey.length() == 0 ? whitespace : whitespace + self.indent;
            foreach [string, anydata[]] arrayTable in arrayTables {
                foreach anydata arrayObject in arrayTable[1] {
                    self.output.push("");
                    self.output.push(newWhitespace + "[[" + arrayTable[0] + "]]");
                    check self.processStructure(<map<anydata>>arrayObject, arrayTable[0], newWhitespace);
                }
            }
        }

        // Construct the standard tables
        if (standardTables.length() > 0) {
            string newWhitespace = tableKey.length() == 0 ? whitespace : whitespace + self.indent;
            foreach [string, map<anydata>] standardTable in standardTables {
                self.output.push("");
                self.output.push(newWhitespace + "[" + standardTable[0] + "]");
                check self.processStructure(standardTable[1], standardTable[0], newWhitespace);
            }
        }
    }

    # Generate the TOML equivalent of the given Ballerina type.
    #
    # + value - Value to converted
    # + return - Converted string on success. Else, an error.
    private function processPrimitiveValue(anydata value) returns string|error {
        if (value is string) {
            return "\"" + value + "\"";
        }

        if (value == 'float:Infinity) {
            return "+inf";
        }

        if (value == -'float:Infinity) {
            return "-inf";
        }

        if (value == 'float:NaN) {
            return "nan";
        }

        if (value is int || value is float || value is boolean || value is map<anydata>) {
            return value.toString();
        }

        return self.generateError("Unknown data type to process");
    }

    # Creates an inline array if there is at least one primitive value.
    # Else, add it to the queue to create an array table.
    #
    # + key - Key of the array  
    # + value - Values of the array  
    # + tableKey - Current table key
    # + arrayTables - List of array tables under the current table  
    # + whitespace - Indentation of the current table
    # + return - An error on failure
    private function processArray(string key, anydata[] value, string tableKey, [string, anydata[]][] arrayTables, string whitespace) returns error? {
        // Check if all the array values are object
        boolean isAllObject = value.reduce(function(boolean assertion, anydata arrayValue) returns boolean {
            return assertion && arrayValue is map<anydata>;
        }, true);

        // Construct an array table
        if (isAllObject) {
            arrayTables.push([self.constructTableKey(tableKey, key), value]);
            return;
        }

        // Construct an inline array
        self.output.push(key + " = [");
        value.forEach(arrayValue => self.output.push(whitespace + self.indent + check self.processPrimitiveValue(arrayValue) + ","));
        self.output.push("]");
    }

    # Creates a dotted key if there is only one value.
    # Else, add it to the queue to create a standard table.
    #
    # + structure - Current table
    # + tableKey - Current table key  
    # + standardTables - List of standard tables under the current table  
    # + whitespace - Indentation of the current table
    # + return - An error on failure
    private function processTable(map<anydata> structure, string tableKey, [string, map<anydata>][] standardTables, string whitespace) returns error? {
        // Check if there are more than one value nested to it.
        if (structure.length() == 1) {
            string firstKey = structure.keys()[0];
            if (structure[firstKey] is map<anydata>) {
                check self.processTable(<map<anydata>>structure[firstKey], self.constructTableKey(tableKey, firstKey), standardTables, whitespace);
            } else {
                self.output.push(whitespace + self.constructTableKey(tableKey, firstKey) + " = " + check self.processPrimitiveValue(structure[firstKey]));
            }
            return;
        }

        // If there are more than two values, construct a standard table.
        standardTables.push([tableKey, structure]);
    }

    # Creates the dotted key for the new table.
    #
    # + parentKey - Key of the parent table
    # + currentKey - Key of the current table
    # + return - Dotted key representing the current table
    private function constructTableKey(string parentKey, string currentKey) returns string {
        return parentKey == "" ? currentKey : parentKey + "." + currentKey;
    }

    # Generates a Parsing Error Error.
    #
    # + message - Error message
    # + return - Constructed Parsing Error message  
    private function generateError(string message) returns WritingError {
        string text = "Writing Error: "
                        + message
                        + ".";
        return error WritingError(text);
    }

}
