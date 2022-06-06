import ballerina/file;

# Checks if the file exists. If not, creates a new file.
#
# + fileName - Path to the file
# + return - An error on failure
public function openFile(string fileName) returns FileError? {
    // Check if the given fileName is not directory
    if check file:test(fileName, file:IS_DIR) {
        return error("Cannot write to a directory");
    }

    // Create the file if the file does not exists
    if !check file:test(fileName, file:EXISTS) {
        check file:create(fileName);
    }
}