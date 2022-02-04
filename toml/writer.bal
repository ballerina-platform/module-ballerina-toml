import ballerina/file;
import ballerina/time;

# Represents an error caused by parser
type WritingError distinct error;

# Handles the process of writing the TOML structure to a file.
class Writer {

    # The table key which the Writer currently processing. 
    # Root if the string is empty.
    private string tableKey;

    private string[] output;

    function init() {
        self.tableKey = "";
        self.output = [];
    }

    # Write the TOML structure to the given file.
    # Follows an extension of the BFS.
    #
    # + structure - TOML structure to be written
    # + return - An error on failure
    public function write(map<anydata> structure) returns string[]|error {
        string[] keys = structure.keys();

        // Traverse all the keys .
        foreach string key in keys {

            // This structure should be processed at the end of this depth level.
            // TODO: Process interal strucutres
            if (structure[key] is map<anydata>) {
                continue;
            }

            if (structure[key] is time:Utc) {
                self.output.push(key + " = " + time:utcToString(<time:Utc>structure[key]));
            }

            // TODO: Process array values
            if (structure[key] is anydata[]) {
                continue;
            }

            self.output.push(key + " = " + check self.processPrimitiveValue(structure[key]));
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

        if (value is int || value is float || value is boolean) {
            return value.toString();
        }

        return self.generateError("Unknown data type to process");
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
