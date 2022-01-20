public class Lexer {
    int index;
    string line;

    function init() {
        self.index = 0;
        self.line = "";
    }

    function getToken() returns Token {
        if (self.index >= self.line.length()-1) {
            self.index = 0;
            self.line = "";
            return {token: EOL}; 
        }

        match self.line[self.index] {
            "#" => {
                return {token: COMMENT};
            }
            " " => {
                self.iterate(self.whitespace);
                return {token: WHITE_SPACE};
            }
        }

        return {token: ERROR};
    }

    private function whitespace(int i) returns boolean {
        return self.line[i] != " ";
    }

    # Encapsulate a function to run isolatedly on the remaining characters
    #
    # + process - Function to be executed on each iteration  
    private function iterate(function (int) returns boolean process) {
        foreach int i in self.index ... self.line.length() - 1 {
            if (process(i)) {
                self.index = i;
                return;
            }
        }
        self.index = self.line.length()-1;
        return;
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
    EOL,
    ERROR
}
