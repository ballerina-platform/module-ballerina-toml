public function read(string tomlString) returns map<any>|error {
    string[] lines = [tomlString];
    Parser parser = new Parser(lines);
    return parser.parse();
}

public function readFile(string filePath) {

}