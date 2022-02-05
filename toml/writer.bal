import ballerina/file;
import ballerina/time;

# Represents an error caused by parser
type WritingError distinct error;

# Handles the process of writing the TOML structure to a file.
class Writer {

    # The table key which the Writer currently processing. 
    # Root if the string is empty.  
    private string tableKey = "";

    # TOML lines to be written
    private string[] output = [];

    # Whitespace for an indent
    private int indentationPolicy;

    function init(int indentationPolicy = 2) {
        self.indentationPolicy = indentationPolicy;
    }

    # Write the TOML structure to the given file.
    # Follows an extension of the BFS.
    #
    # + structure - TOML structure to be written
    # + return - An error on failure
    public function write(map<anydata> structure) returns string[]|error {
        check self.processStructure(structure, 0, "");

        // Remove the start of document whitespace if exists.
        if (self.output[0] == " ") {
            _ = self.output.remove(0);
        }

        return self.output;
    }

    # Checks izf the file exists. If not, creates a new file.
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

    private function processStructure(map<anydata> structure, int depth, string tableKey) returns error? {
        string[] keys = structure.keys();

        // List of array tables to be created
        [string, anydata[]][] arrayTables = [];

        // List of standard tables to be created
        [string, map<anydata>][] standardTables = [];

        // Indentation of the key
        string whitespace = self.getWhitespace(depth);

        // Traverse all the keys .
        foreach string key in keys {
            anydata value = structure[key];

            // This structure should be processed at the end of this depth level
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
                check self.processArray(key, value, arrayTables, whitespace);
                continue;
            }

            self.output.push(whitespace + key + " = " + check self.processPrimitiveValue(value));
        }

        // Construct the array tables
        if (arrayTables.length() > 0) {
            foreach [string, anydata[]] arrayTable in arrayTables {
                foreach anydata arrayObject in arrayTable[1] {
                    self.output.push("");
                    self.output.push(whitespace + "[[" + arrayTable[0] + "]]");
                    check self.processStructure(<map<anydata>>arrayObject, depth + 1, arrayTable[0]);
                }
            }
        }

        // Construct the standard tables
        if (standardTables.length() > 0) {
            foreach [string, map<anydata>] standardTable in standardTables {
                self.output.push("");
                self.output.push(whitespace + "[" + standardTable[0] + "]");
                check self.processStructure(standardTable[1], depth + 1, standardTable[0]);
            }
        }
    }

    # Generate the TOML equivalent of the given Ballerina type
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

    private function processArray(string key, anydata[] value, [string, anydata[]][] arrayTables, string whitespace) returns error? {
        boolean isAllObject = value.reduce(function(boolean assertion, anydata arrayValue) returns boolean {
            return assertion && arrayValue is map<anydata>;
        }, true);

        // Construct an array table
        if (isAllObject) {
            arrayTables.push([key, value]);
            return;
        }

        // Construct an inline array
        self.output.push(key + " = [");
        value.forEach(arrayValue => self.output.push(whitespace + check self.processPrimitiveValue(arrayValue) + ","));
        self.output.push("]");
    }

    private function processTable(map<anydata> structure, string tableKey, [string, map<anydata>][] standardTables, string whitespace) returns error? {
        // Check if there are more than one value nested to it.
        if (structure.length() == 1) {
            string firstKey = structure.keys()[0];
            if (structure[firstKey] is map<anydata>) {
                check self.processTable(<map<anydata>>structure[firstKey], self.constructTableKey(tableKey, firstKey), standardTables, whitespace);
            } else {
                self.output.push(whitespace + self.constructTableKey(tableKey, firstKey) + " = " + check self.processPrimitiveValue(structure[firstKey]));
            }
        }

        // If there are more than two values, construct a standard table.
        standardTables.push([tableKey, structure]);
        return;
    }

    private function constructTableKey(string parentKey, string currentKey) returns string {
        return parentKey == "" ? currentKey : parentKey + "." + currentKey;
    }

    private function getWhitespace(int depth) returns string {
        string whitespace = "";
        foreach int i in 1 ... self.indentationPolicy * depth {
            whitespace += " ";
        }
        return whitespace;
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
