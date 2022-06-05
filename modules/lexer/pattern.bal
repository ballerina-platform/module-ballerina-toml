function patternBinary(string:Char char) returns boolean
    => char is "0"|"1";

function patternOctal(string:Char char) returns boolean
    => char is "0"|"1"|"2"|"3"|"4"|"5"|"6"|"7";

function patternDecimal(string:Char char) returns boolean
    => char is "0"|"1"|"2"|"3"|"4"|"5"|"6"|"7"|"8"|"9";

function patternHexadecimal(string:Char char) returns boolean
    => char is "0"|"1"|"2"|"3"|"4"|"5"|"6"|"7"|"8"|"9"|"A"|"B"|"C"|"D"|"E"|"F"|"a"|"b"|"c"|"d"|"e"|"f";

function patternUnquotedString(string:Char char) returns boolean {
    int codePoint = char.toCodePointInt();

    return (codePoint >= 97 && codePoint <= 122)
        || (codePoint >= 65 && codePoint <= 90)
        || patternDecimal(char)
        || char is "-"|"_";
}

function patternBasicString(string:Char char) returns boolean {
    int codePoint = char.toCodePointInt();

    return (codePoint >= 35 && codePoint <= 91)
        || (codePoint >= 93 && codePoint <= 126)
        || (codePoint >= 128 && codePoint <= 55295)
        || (codePoint >= 57344 && codePoint <= 1114111)
        || codePoint is 9|32|33|144;
}

function patternLiteralString(string:Char char) returns boolean {
    int codePoint = char.toCodePointInt();

    return (codePoint >= 9 && codePoint <= 38)
        || (codePoint >= 40 && codePoint <= 126)
        || (codePoint >= 128 && codePoint <= 55295)
        || (codePoint >= 57344 && codePoint <= 1114111)
        || codePoint == 32;
}
