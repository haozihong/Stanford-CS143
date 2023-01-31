/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;
int string_err; // 0: no err; 1: too long; 2: null char

void string_buf_append(char *s, int leng) {
  if (string_err) return;
  if (string_buf_ptr - string_buf + leng >= MAX_STR_CONST) {
      string_err = 1;
      return;
    }
    while (leng--) *string_buf_ptr++ = *s++;
}

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
int comment_layer = 0;

%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>
DIGIT           [0-9]
WHITESPACE      [ \f\r\t\v]

%x str
%x inline_comment
%x comment

%%

 // inline comments
--                      BEGIN(inline_comment);

<inline_comment>.*      { /* do nothing */ }

<inline_comment>\n      curr_lineno++; BEGIN(INITIAL);
<inline_comment><<EOF>> BEGIN(INITIAL);


 /*
  *  Nested comments
  */
<INITIAL,comment>"(*" {
  comment_layer++;
  BEGIN(comment);
}

<comment>\n         curr_lineno++;

<comment>\(         |
<comment>\*         |
<comment>[^\*\n\(]* {/* do nothing */}

<comment>"*)"       if (--comment_layer == 0) BEGIN(INITIAL);

<comment><<EOF>>  {
  BEGIN(INITIAL);
  cool_yylval.error_msg = "EOF in comment";
  return ERROR;
}

"*)"  cool_yylval.error_msg = "Unmatched *)"; return ERROR;

 /*
  *  The multiple-character operators.
  */
"=>"		      { return DARROW; }
"<-"          { return ASSIGN; }
"<="          { return LE; }


 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
t(?i:rue)     { cool_yylval.boolean = 1; return BOOL_CONST; }
f(?i:alse)    { cool_yylval.boolean = 0; return BOOL_CONST; }

(?i:CLASS)    { return CLASS; }
(?i:ELSE)     { return ELSE; }
(?i:FI)       { return FI; }
(?i:IF)       { return IF; }
(?i:IN)       { return IN; }
(?i:INHERITS) { return INHERITS; }
(?i:LET)      { return LET; }
(?i:LOOP)     { return LOOP; }
(?i:POOL)     { return POOL; }
(?i:THEN)     { return THEN; }
(?i:WHILE)    { return WHILE; }
(?i:CASE)     { return CASE; }
(?i:ESAC)     { return ESAC; }
(?i:OF)       { return OF; }
(?i:NEW)      { return NEW; }
(?i:ISVOID)   { return ISVOID; }
(?i:NOT)      { return NOT; }


 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
\" {
  string_buf_ptr = string_buf;
  string_err = 0;
  BEGIN(str);
}

<str>{
  \" {
    BEGIN(INITIAL);
    switch (string_err) {
      case 1:
        cool_yylval.error_msg = "String constant too long";
        return ERROR;
      case 2:
        cool_yylval.error_msg = "String contains null character";
        return ERROR;
      default:
        *string_buf_ptr = '\0';
        yylval.symbol = stringtable.add_string(string_buf);
        return STR_CONST;
    }
  }

   /* assume the programmer simply forgot the close-quote */
  \n {
    BEGIN(INITIAL);
    curr_lineno++;
    cool_yylval.error_msg = "Unterminated string constant";
    return ERROR;
  }

  <<EOF>> {
    BEGIN(INITIAL);
    cool_yylval.error_msg = "EOF in string constant";
    return ERROR;
  }

  \\\0  |
  \0    string_err = 2;

  \\b           string_buf_append("\b", 1);
  \\t           string_buf_append("\t", 1);
  \\n           string_buf_append("\n", 1);
  \\f           string_buf_append("\f", 1);
  \\.           string_buf_append(yytext + 1, 1);
  \\\n          string_buf_append("\n", 1); curr_lineno++;
  [^\"\0\n\\]+  string_buf_append(yytext, yyleng);
}


 /* Integer constants */
{DIGIT}+ {
  yylval.symbol = inttable.add_string(yytext);
  return INT_CONST;
}


 /* Type identifiers */
[A-Z](?i:[0-9a-z_]*) {
  yylval.symbol = idtable.add_string(yytext);
  return TYPEID;
}


 /* object identifiers */
[a-z](?i:[0-9a-z_]*) {
  yylval.symbol = idtable.add_string(yytext);
  return OBJECTID;
}


 /* new line */
\n curr_lineno++;


{WHITESPACE}+ { /* do nothing */ }


 /* Single char */
 [\.@\+\-\*\/~<=;,:\(\)\{\}] return yytext[0]; 

 /* invalid char */
. cool_yylval.error_msg = yytext; return ERROR;
%%
