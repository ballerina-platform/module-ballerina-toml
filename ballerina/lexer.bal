public class Lexer {
    int lastIndex;
    string line;

    function init() {
        self.lastIndex = 0;
        self.line = "";
    }

    function getToken() returns Token {
        foreach int i in self.lastIndex...self.line.length() {

            match self.line[i] {
                "#" => {       
                    return {token: COMMENT};
                }
                " " => {
                    self.iterate(i, self.whitespace);
                    return {token: WHITE_SPACE};
                }
            }
        }
        return {token: EOL};
    }

    private function whitespace(int i) {
        if (self.line[i] != " ") {
            return;
        }
    }

    private function iterate(int j, function(int) process) {
        foreach int i in j...self.line.length() {
            process(i);
        }
    }
}

type Token record {|
    TOMLToken token;
    string value = "";
|};

enum TOMLToken {
    EXPRESSION,
    COMMENT,
    WHITE_SPACE,
    KEY_VALUE,
    EOL
}
