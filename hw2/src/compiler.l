/* Definition section */
%option yymore
%{
    #include <stdlib.h>
    #include <string.h>
    #include <utf8.c/utf8.h>
    #include "chinese_number.h"
    #include "compiler_util.h"

    #define YY_NO_UNPUT
    #define YY_NO_INPUT

    int yycolumnUtf8, yylengUtf8, yytokenLine = 1;
    utf8_string yytextUtf8;

    static inline void updateNewline() {
        // TODO: Update the line number and column number
        yycolumnUtf8 = 0;
        yylengUtf8 = 0;
        yytokenLine = yylineno;
    }

    /* Calculates UTF-8 character length to update the column counters */
    static inline void processUtf8Char() {
        yytextUtf8 = make_utf8_string(yytext);
        if (yytextUtf8.str) {
            // TODO: Calculate the column number
            // every time flex matches a token, count how many UTF-8 char are in yytext, then update the column tracker
            yylengUtf8 = utf8_char_count(yytextUtf8);
            yycolumnUtf8 += yylengUtf8;
        }
    }

    /* Appends the next matched token and reverting the column counters to the start of the string */
    static inline void yymore_utf8() {
        yymore();
        if (yytextUtf8.str) {
            // TODO: Reset column
            yycolumnUtf8 -= yylengUtf8;
        }
    }

    #define YY_USER_ACTION \
        processUtf8Char();

    #define PRINT_TOKEN(format, ...) printf("%d:%d: " format "\n", yytokenLine, yycolumnUtf8 - yylengUtf8 + 1, __VA_ARGS__)

    /* Extracts string from the current token by specified padding */
    char* trimStringToken(int paddLen) {
        static char cache[4096];
        // TODO: Slice the string and copy

        int len = yyleng - paddLen * 2;
        if (len >= (int) sizeof(cache)) {
            len = (int) sizeof(cache) - 1;
        }
        strncpy(cache, yytext + paddLen, len);
        cache[len] = '\0';

        return cache;
    }
%}

/* Define regular expression label */
digit ("零"|"〇"|"一"|"二"|"三"|"四"|"五"|"六"|"七"|"八"|"九"|"兩"|"壹"|"貳"|"參"|"肆"|"伍"|"陸"|"柒"|"捌"|"玖")
num_unit ("十"|"百"|"千"|"萬"|"億"|"兆"|"京"|"垓"|"秭"|"穰"|"溝"|"澗"|"正"|"載"|"極"|"拾"|"佰"|"仟")
frac_unit ("分"|"釐"|"毫"|"絲"|"忽"|"微"|"纖"|"沙"|"塵"|"埃"|"渺"|"漠")
number_char ("負"|"·"|"又"|{digit}|{num_unit}|{frac_unit})
COMMENT ("注曰"|"疏曰"|"批曰")
HERE_ARE ("今有"|"吾有")
HERE_IS_A "有"
SAID "曰"
NAME_IT "名之曰"
VAR_TYPE ("長"|"數"|"言"|"爻"|"元"|"列")
VAR_TYPE_FUNC "術"

UTF8_BOM "\357\273\277"

ASCII   [\x00-\x7f]
U       [\x80-\xbf]

B2      [\xC2-\xDF]{U}
B3_1    \xE0[\xA0-\xBF]{U}
B3_2    [\xE1-\xEC]{U}{U}
B3_3    \xED[\x80-\x9F]{U}
B3_4    [\xEE-\xEF]{U}{U}
B4_1    \xF0[\x90-\xBF]{U}{U}
B4_2    [\xF1-\xF3]{U}{U}{U}
B4_3    \xF4[\x80-\x8F]{U}{U}

/* ALL UTF-8 https://www.w3.org/2005/03/23-lex-U#charRange
  {ASCII}
| ([\xC2-\xDF] {U})
| ( \xE0       [\xA0-\xBF]{U})
| ([\xE1-\xEC] {U}{U})
| ( \xED       [\x80-\x9F]{U})
| ([\xEE-\xEF] {U}{U})
| ( \xF0       [\x90-\xBF]{U}{U})
| ([\xF1-\xF3] {U}{U}{U})
| ( \xF4       [\x80-\x8F]{U}{U})
*/

ALL_UTF8 {ASCII}|{B2}|{B3_1}|{B3_2}|{B3_3}|{B3_4}|{B4_1}|{B4_2}|{B4_3}

B3_2_EXCLUDE_QUO ([\xE1-\xE2]{U}{U})|(\xE3\x80[\x80-\x8C\x8E-\xBF])|(\xE3[\x81-\xBF]{U})|([\xE4-\xEC]{U}{U})

EXCLUDE_QUO [\x20-\x7E]|{B2}|{B3_1}|{B3_2_EXCLUDE_QUO}|{B3_3}|{B3_4}|{B4_1}|{B4_2}|{B4_3}

%option yylineno
%x IDENT_CON STR_CON


 /* Rules section */
%%
{UTF8_BOM}  { updateNewline(); /* Skip UTF-8 BOM */ }

"「「"        { BEGIN(STR_CON); yymore_utf8(); }
<STR_CON>"」"/"」」" { yymore_utf8(); }
<STR_CON>"」」"    { BEGIN(INITIAL); PRINT_TOKEN("STR_LIT \"%s\"", trimStringToken(6)); }
<STR_CON>\r?\n    { yymore_utf8(); }
<STR_CON>{EXCLUDE_QUO}+    { yymore_utf8(); }
<STR_CON>"」"    { yymore_utf8(); }

"「"        { BEGIN(IDENT_CON); yymore_utf8(); }
<IDENT_CON>"」"    { BEGIN(INITIAL); PRINT_TOKEN("IDENT '%s'", trimStringToken(3)); }
<IDENT_CON>\r?\n    { yymore_utf8(); }
<IDENT_CON>{EXCLUDE_QUO}+    { yymore_utf8(); }

{COMMENT}   { PRINT_TOKEN("COMMENT %s", yytext); }
{NAME_IT}   { PRINT_TOKEN("NAME_IT %s", yytext); }
{HERE_ARE}  { PRINT_TOKEN("HERE_ARE %s", yytext); }
{HERE_IS_A} { PRINT_TOKEN("HERE_IS_A %s", yytext); }

"欲行是術" { PRINT_TOKEN("TO_PERFORM_FUNC %s", yytext); }
"必先得" { PRINT_TOKEN("REQUIRE_ARGS %s", yytext); }
"乃行是術曰"|"乃是術曰" { PRINT_TOKEN("FUNC_BEGIN %s", yytext); }
"是謂" { PRINT_TOKEN("FUNC_END_FOR %s", yytext); }
"之術也" { PRINT_TOKEN("FUNC_END %s", yytext); }
"施" { PRINT_TOKEN("CALL %s", yytext); }

"中有陽乎" { PRINT_TOKEN("EXP_LOGIC %s", "||"); }
"中無陰乎" { PRINT_TOKEN("EXP_LOGIC %s", "&&"); }
"不大於" { PRINT_TOKEN("EXP_LOGIC %s", "<="); }
"不小於" { PRINT_TOKEN("EXP_LOGIC %s", ">="); }
"不等於" { PRINT_TOKEN("EXP_LOGIC %s", "!="); }
"大於" { PRINT_TOKEN("EXP_LOGIC %s", ">"); }
"小於" { PRINT_TOKEN("EXP_LOGIC %s", "<"); }
"等於" { PRINT_TOKEN("EXP_LOGIC %s", "=="); }

"若非" { PRINT_TOKEN("ELSE %s", yytext); }
"或若" { PRINT_TOKEN("ELSE_IF %s", yytext); }
"若" { PRINT_TOKEN("IF %s", yytext); }
"恆為是" { PRINT_TOKEN("WHILE_TRUE %s", yytext); }
"為是" { PRINT_TOKEN("FOR %s", yytext); }
"遍" { PRINT_TOKEN("TIMES %s", yytext); }
"乃止" { PRINT_TOKEN("BREAK %s", yytext); }
"乃得" { PRINT_TOKEN("RETURN %s", yytext); }

"所餘幾何" { PRINT_TOKEN("EXP_MATH_OP %s", "%"); }
"加" { PRINT_TOKEN("EXP_MATH %s", "+"); }
"減" { PRINT_TOKEN("EXP_MATH %s", "-"); }
"乘" { PRINT_TOKEN("EXP_MATH %s", "*"); }
"除" { PRINT_TOKEN("EXP_MATH %s", "/"); }
"於" { PRINT_TOKEN("%s", "<-"); }
"以" { PRINT_TOKEN("%s", "->"); }

"書之" { PRINT_TOKEN("PRINT %s", yytext); }
"之長" { PRINT_TOKEN("LENGTH %s", yytext); }
"昔之" { PRINT_TOKEN("PAST %s", yytext); }
"是矣" { PRINT_TOKEN("IS_THUS %s", yytext); }
"之" { PRINT_TOKEN("INDEX %s", yytext); }
"者" { PRINT_TOKEN("TOPIC %s", yytext); }
"今" { PRINT_TOKEN("SET %s", yytext); }
"其" { PRINT_TOKEN("ITS %s", yytext); }
"充" { PRINT_TOKEN("PUSH %s", yytext); }
"夫" { PRINT_TOKEN("THOSE %s", yytext); }
"取" { PRINT_TOKEN("TAKE %s", yytext); }
"曰" { PRINT_TOKEN("SAID %s", yytext); }

"云云"|"也"|"矣" { PRINT_TOKEN("END %s", yytext); }

{VAR_TYPE_FUNC} { PRINT_TOKEN("VAR_TYPE_FUNC %s", yytext); }
{VAR_TYPE}      { PRINT_TOKEN("VAR_TYPE %s", yytext); }
"陽" { PRINT_TOKEN("BOOL_LIT %s", "true"); }
"陰" { PRINT_TOKEN("BOOL_LIT %s", "false"); }

{number_char}+ {
    ScientificNotation sci;
    if (!chineseToArabic(yytext, &sci)) {
        char* number = sciToStr(&sci);
        char* integerExp = strstr(number, ".0e+00");
        if (integerExp && integerExp[6] == '\0') {
            *integerExp = '\0';
        }
        PRINT_TOKEN("NUMBER_LIT %s", number);
        free(number);
    }
}

[ \t]+      {}
\r?\n       { updateNewline(); }
("。"|"，") {}

<<EOF>>     { yyterminate(); }

{ALL_UTF8} { PRINT_TOKEN("UNKNOWN CHAR %s", yytext); }
. { PRINT_TOKEN("UNKNOWN CHAR %s", yytext); }
%%
/*  C Code section */
int yywrap(void) {
    return 1;
}
