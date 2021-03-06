/*
** 2001 September 15
**
** The author disclaims copyright to this source code.  In place of
** a legal notice, here is a blessing:
**
**    May you do good and not evil.
**    May you find forgiveness for yourself and forgive others.
**    May you share freely, never taking more than you give.
**
*************************************************************************
** This file contains SQLite's grammar for SQL.  Process this file
** using the lemon parser generator to generate C code that runs
** the parser.  Lemon will also generate a header file containing
** numeric codes for all of the tokens.
**
** @(#) $Id: parse.y,v 1.199 2006/03/13 12:54:10 drh Exp $
*/

// All token codes are small integers with #defines that begin with "TK_"
%token_prefix TK_

// The type of the data attached to each token is Token.  This is also the
// default type for non-terminals.
//
%token_type {Token}
%default_type {Token}

// The generated parser function takes a 4th argument as follows:
%extra_argument {Parse *pParse}

// This code runs whenever there is a syntax error
//
%syntax_error {
  if( pParse->zErrMsg==0 ){
    if( TOKEN.z[0] ){
      sqlite3ErrorMsg(pParse, "near \"%T\": syntax error", &TOKEN);
    }else{
      sqlite3ErrorMsg(pParse, "incomplete SQL statement");
    }
  }
}
%stack_overflow {
  sqlite3ErrorMsg(pParse, "parser stack overflow");
}

// The name of the generated procedure that implements the parser
// is as follows:
%name Parser

// The following text is included near the beginning of the C source
// code file that implements the parser.
//
%include {
#include "sqliteInt.h"
#include "parse.h"

/*
** An instance of this structure holds information about the
** LIMIT clause of a SELECT statement.
*/
struct LimitVal {
  Expr *pLimit;    /* The LIMIT expression.  NULL if there is no limit */
  Expr *pOffset;   /* The OFFSET expression.  NULL if there is none */
};

/*
** An instance of this structure is used to store the LIKE,
** GLOB, NOT LIKE, and NOT GLOB operators.
*/
struct LikeOp {
  Token eOperator;  /* "like" or "glob" or "regexp" */
  int not;         /* True if the NOT keyword is present */
};

/*
** An instance of the following structure describes the event of a
** TRIGGER.  "a" is the event type, one of TK_UPDATE, TK_INSERT,
** TK_DELETE, or TK_INSTEAD.  If the event is of the form
**
**      UPDATE ON (a,b,c)
**
** Then the "b" IdList records the list "a,b,c".
*/
struct TrigEvent { int a; IdList * b; };

/*
** An instance of this structure holds the ATTACH key and the key type.
*/
struct AttachKey { int type;  Token key; };

} // end %include

// Input is a single SQL command
input ::= cmdlist.
cmdlist ::= cmdlist ecmd.
cmdlist ::= ecmd.
cmdx ::= cmd.           { }
cmdx ::= LP cmd RP.     { pParse->sflag |= SQL_FLAG_CODING;}
ecmd ::= SEMI.
ecmd ::= explain cmdx SEMI.
explain ::= .           { }
%ifndef SQLITE_OMIT_EXPLAIN
explain ::= EXPLAIN.              { pParse->sflag |= SQL_FLAG_PARSE; }
explain ::= EXPLAIN QUERY PLAN.   { pParse->sflag |= SQL_FLAG_PARSE; }
%endif

///////////////////// Begin and end transactions. ////////////////////////////
//

//cmd ::= BEGIN transtype(Y) trans_opt.  { pParse->sflag |= SQL_FLAG_TR;}
cmd ::= BEGIN trans_opt.  { pParse->sflag |= SQL_FLAG_TR;}
cmd ::= START TRANSACTION. { pParse->sflag |= SQL_FLAG_TR;}
trans_opt ::= .
trans_opt ::= WORK.
//trans_opt ::= TRANSACTION.
//trans_opt ::= TRANSACTION nm.

//%type transtype {int}
//transtype(A) ::= .             {A = TK_DEFERRED;}
//transtype(A) ::= DEFERRED(X).  {A = @X;}
//transtype(A) ::= IMMEDIATE(X). {A = @X;}
//transtype(A) ::= EXCLUSIVE(X). {A = @X;}
cmd ::= COMMIT trans_opt.      { pParse->sflag |= SQL_FLAG_TR; }
//cmd ::= END trans_opt.         { pParse->sflag |= SQL_FLAG_TR; }
cmd ::= ROLLBACK trans_opt.    { pParse->sflag |= SQL_FLAG_TR; }

///////////////////// The CREATE TABLE statement ////////////////////////////
//
cmd ::= create_table create_table_args.
create_table ::= CREATE temp TABLE ifnotexists nm dbnm. {
   pParse->sflag |= SQL_FLAG_TABLE;
}

%type ifnotexists {int}
ifnotexists(A) ::= .              {A = 0;}
ifnotexists(A) ::= IF NOT EXISTS. {A = 1;}
%type temp {int}
%ifndef SQLITE_OMIT_TEMPDB
temp(A) ::= TEMP.  {A = 1;}
%endif
temp(A) ::= .      {A = 0;}
create_table_args ::= LP columnlist conslist_opt RP table_opt. {
  //sqlite3EndTable(pParse,&X,&Y,0);
}
create_table_args ::= AS select. {
	pParse->sflag |= SQL_FLAG_TABLE;
}
columnlist ::= columnlist COMMA column.
columnlist ::= column.

// -- TODO FAKE grammer-- TO COMPLETE THIS
table_opt ::= .
table_opt ::= table_opt ID.
table_opt ::= table_opt ID EQ ID.
table_opt ::= table_opt DEFAULT CHARSET SET eq_or_null ID.
table_opt ::= table_opt DEFAULT COLLATE eq_or_null ID.

eq_or_null ::= .
eq_or_null ::= EQ.

// A "column" is a complete description of a single column in a
// CREATE TABLE statement.  This includes the column name, its
// datatype, and other keywords such as PRIMARY KEY, UNIQUE, REFERENCES,
// NOT NULL and so forth.
//
column ::= columnid type carglist. {
  //A.z = X.z;
  //A.n = (pParse->sLastToken.z-X.z) + pParse->sLastToken.n;
}
columnid ::= nm. {
  //sqlite3AddColumn(pParse,&X);
  //A = X;
}


// An IDENTIFIER can be a generic identifier, or one of several
// keywords.  Any non-standard keyword can also be an identifier.
//
%type id {Token}
id(A) ::= ID(X).         {A = X;}

// The following directive causes tokens ABORT, AFTER, ASC, etc. to
// fallback to ID if they will not parse as their original value.
// This obviates the need for the "id" nonterminal.
//
%fallback ID
  ABORT AFTER ANALYZE ASC ATTACH BEFORE BEGIN CASCADE CAST CONFLICT
  DATABASE DEFERRED DESC DETACH EACH END EXCLUSIVE EXPLAIN FAIL FOR
  IGNORE IMMEDIATE INITIALLY INSTEAD LIKE_KW MATCH PLAN QUERY KEY
  OF OFFSET PRAGMA RAISE REPLACE RESTRICT ROW STATEMENT
  TEMP TRIGGER VACUUM VIEW 
%ifdef SQLITE_OMIT_COMPOUND_SELECT
  EXCEPT INTERSECT UNION
%endif
  REINDEX RENAME CTIME_KW IF
  .

// Define operator precedence early so that this is the first occurance
// of the operator tokens in the grammer.  Keeping the operators together
// causes them to be assigned integer values that are close together,
// which keeps parser tables smaller.
//
// The token values assigned to these symbols is determined by the order
// in which lemon first sees them.  It must be the case that ISNULL/NOTNULL,
// NE/EQ, GT/LE, and GE/LT are separated by only a single value.  See
// the sqlite3ExprIfFalse() routine for additional information on this
// constraint.
//
%left OR.
%left AND.
%right NOT.
%left IS LIKE_KW BETWEEN IN ISNULL NOTNULL NE EQ.
%left GT LE LT GE.
%right ESCAPE.
%left BITAND BITOR LSHIFT RSHIFT.
%left PLUS MINUS.
%left STAR SLASH REM.
%left CONCAT.
%right UMINUS UPLUS BITNOT.

// And "ids" is an identifer-or-string.
//
%type ids {Token}
ids(A) ::= ID|STRING(X).   {A = X;}

// The name of a column or table can be any of the following:
//
%type nm {Token}
nm(A) ::= ID(X).         {A = X;}
nm(A) ::= STRING(X).     {A = X;}
nm(A) ::= JOIN_KW(X).    {A = X;}

// A typetoken is really one or more tokens that form a type name such
// as can be found after the column name in a CREATE TABLE statement.
// Multiple tokens are concatenated to form the value of the typetoken.
//
%type typetoken {Token}
type ::= .
type ::= typetoken.                   { /*sqlite3AddColumnType(pParse,&X);*/ }
typetoken(A) ::= typename(X).   {A = X;}
typetoken(A) ::= typename(X) LP signed RP(Y). {
  A.z = X.z;
  A.n = &Y.z[Y.n] - X.z;
}
typetoken(A) ::= typename(X) LP signed COMMA signed RP(Y). {
  A.z = X.z;
  A.n = &Y.z[Y.n] - X.z;
}
%type typename {Token}
typename(A) ::= ids(X).             {A = X;}
typename(A) ::= typename(X) ids(Y). {A.z=X.z; A.n=Y.n+(Y.z-X.z);}
%type signed {int}
signed(A) ::= plus_num(X).    { A = atoi((char*)X.z); }
signed(A) ::= minus_num(X).   { A = -atoi((char*)X.z); }

// "carglist" is a list of additional constraints that come after the
// column name and column type in a CREATE TABLE statement.
//
carglist ::= carglist carg.
carglist ::= .
carg ::= CONSTRAINT nm ccons.
carg ::= ccons.
carg ::= DEFAULT term.            { /*sqlite3AddDefaultValue(pParse,X);*/ }
carg ::= DEFAULT LP expr RP.      { /*sqlite3AddDefaultValue(pParse,X);*/ }
carg ::= DEFAULT PLUS term.       { /*sqlite3AddDefaultValue(pParse,X);*/}
carg ::= DEFAULT MINUS term.      {
  //Expr *p = sqlite3Expr(TK_UMINUS, X, 0, 0);
  //sqlite3AddDefaultValue(pParse,p);
}
carg ::= DEFAULT id.              {
  //Expr *p = sqlite3Expr(TK_STRING, 0, 0, &X);
  //sqlite3AddDefaultValue(pParse,p);
}

// In addition to the type name, we also care about the primary key and
// UNIQUE constraints.
//
ccons ::= AUTOINCR.
ccons ::= NULL onconf.
ccons ::= NOT NULL onconf.               {/*sqlite3AddNotNull(pParse, R);*/}
ccons ::= PRIMARY KEY sortorder onconf.
                                     {/*sqlite3AddPrimaryKey(pParse,0,R,I,Z);*/}
ccons ::= UNIQUE onconf.    {/*sqlite3CreateIndex(pParse,0,0,0,0,R,0,0,0,0);*/}
ccons ::= CHECK LP expr RP.       { }
ccons ::= REFERENCES nm idxlist_opt refargs.
                                { }
ccons ::= defer_subclause.   {/*sqlite3DeferForeignKey(pParse,D);*/}
ccons ::= COLLATE id.  {/*sqlite3AddCollateType(pParse, (char*)C.z, C.n);*/}

// The optional AUTOINCREMENT keyword
%type autoinc {int}
autoinc(X) ::= .          {X = 0;}
autoinc(X) ::= AUTOINCR.  {X = 1;}

// The next group of rules parses the arguments to a REFERENCES clause
// that determine if the referential integrity checking is deferred or
// or immediate and which determine what action to take if a ref-integ
// check fails.
//
%type refargs {int}
refargs(A) ::= .                     { A = OE_Restrict * 0x010101; }
refargs(A) ::= refargs(X) refarg(Y). { A = (X & Y.mask) | Y.value; }
%type refarg {struct {int value; int mask;}}
refarg(A) ::= MATCH nm.              { A.value = 0;     A.mask = 0x000000; }
refarg(A) ::= ON DELETE refact(X).   { A.value = X;     A.mask = 0x0000ff; }
refarg(A) ::= ON UPDATE refact(X).   { A.value = X<<8;  A.mask = 0x00ff00; }
refarg(A) ::= ON INSERT refact(X).   { A.value = X<<16; A.mask = 0xff0000; }
%type refact {int}
refact(A) ::= SET NULL.              { A = OE_SetNull; }
refact(A) ::= SET DEFAULT.           { A = OE_SetDflt; }
refact(A) ::= CASCADE.               { A = OE_Cascade; }
refact(A) ::= RESTRICT.              { A = OE_Restrict; }
%type defer_subclause {int}
defer_subclause(A) ::= NOT DEFERRABLE init_deferred_pred_opt(X).  {A = X;}
defer_subclause(A) ::= DEFERRABLE init_deferred_pred_opt(X).      {A = X;}
%type init_deferred_pred_opt {int}
init_deferred_pred_opt(A) ::= .                       {A = 0;}
init_deferred_pred_opt(A) ::= INITIALLY DEFERRED.     {A = 1;}
init_deferred_pred_opt(A) ::= INITIALLY IMMEDIATE.    {A = 0;}

// For the time being, the only constraint we care about is the primary
// key and UNIQUE.  Both create indices.
//
conslist_opt ::= .                   
conslist_opt ::= COMMA conslist.  
conslist ::= conslist COMMA tcons.
conslist ::= conslist tcons.
conslist ::= tcons.
tcons ::= CONSTRAINT nm.

// -- TODO --
// idxlist and idxlist_opt need to explicit call its destructor, or will make memleak, do not know why it don't call automatically...
tcons ::= PRIMARY KEY LP idxlist autoinc RP onconf. { }
tcons ::= UNIQUE LP idxlist RP onconf.
                                 { }
tcons ::= CHECK LP expr RP onconf. { }
tcons ::= FOREIGN KEY LP idxlist RP
          REFERENCES nm idxlist_opt refargs defer_subclause_opt. { 
 }

%type defer_subclause_opt {int}
defer_subclause_opt(A) ::= .                    {A = 0;}
defer_subclause_opt(A) ::= defer_subclause(X).  {A = X;}

// The following is a non-standard extension that allows us to declare the
// default behavior when there is a constraint conflict.
//
%type onconf {int}
%type orconf {int}
%type resolvetype {int}
onconf(A) ::= .                              {A = OE_Default;}
onconf(A) ::= ON CONFLICT resolvetype(X).    {A = X;}
//orconf(A) ::= .                              {A = OE_Default;}
//orconf(A) ::= OR resolvetype(X).             {A = X;}
resolvetype(A) ::= raisetype(X).             {A = X;}
resolvetype(A) ::= IGNORE.                   {A = OE_Ignore;}
resolvetype(A) ::= REPLACE.                  {A = OE_Replace;}

////////////////////////// The DROP TABLE /////////////////////////////////////
//
cmd ::= DROP TABLE ifexists fullname. {
  pParse->sflag |= SQL_FLAG_TABLE;
}
%type ifexists {int}
ifexists(A) ::= IF EXISTS.   {A = 1;}
ifexists(A) ::= .            {A = 0;}

///////////////////// The CREATE VIEW statement /////////////////////////////
//
%ifndef SQLITE_OMIT_VIEW
//cmd ::= CREATE(X) temp(T) VIEW nm(Y) dbnm(Z) AS select(S). {
//  sqlite3CreateView(pParse, &X, &Y, &Z, S, T);
//}
//cmd ::= DROP VIEW ifexists(E) fullname(X). {
//  sqlite3DropTable(pParse, X, 1, E);
//}
%endif // SQLITE_OMIT_VIEW

//////////////////////// The SELECT statement /////////////////////////////////
//
cmd ::= select.  {
}

%type select {Select*}
//%destructor select { }
%type oneselect {Select*}
//%destructor oneselect { }

select(A) ::= oneselect(X).                      {A = X;}
%ifndef SQLITE_OMIT_COMPOUND_SELECT
select(A) ::= select(X) multiselect_op(Y) oneselect(Z).  {
  if( Z ){
    Z->op = Y;
    Z->pPrior = X;
  }
  A = Z;
}
%type multiselect_op {int}
multiselect_op(A) ::= UNION(OP).             {A = @OP;}
multiselect_op(A) ::= UNION ALL.             {A = TK_ALL;}
multiselect_op(A) ::= EXCEPT|INTERSECT(OP).  {A = @OP;}
%endif // SQLITE_OMIT_COMPOUND_SELECT
oneselect ::= SELECT distinct selcollist from where_opt
                 groupby_opt having_opt orderby_opt limit_opt. {
  pParse->select_num++;
}

// The "distinct" nonterminal is true (1) if the DISTINCT keyword is
// present and false (0) if it is not.
//
%type distinct {int}
distinct(A) ::= DISTINCT.   {A = 1;}
distinct(A) ::= ALL.        {A = 0;}
distinct(A) ::= .           {A = 0;}

// selcollist is a list of expressions that are to become the return
// values of the SELECT statement.  The "*" in statements like
// "SELECT * FROM ..." is encoded as a special expression with an
// opcode of TK_ALL.
//
%type selcollist {ExprList*}
%destructor selcollist { }
%type sclp {ExprList*}
%destructor sclp { }
sclp(A) ::= selcollist(X) COMMA.             {A = X;}
sclp(A) ::= .                                {A = 0;}
selcollist ::= sclp expr as.     {
  pParse->sflag |= SQL_FLAG_EXPR;
}
selcollist ::= sclp STAR. {
  pParse->sflag |= SQL_FLAG_EXPR;
}
selcollist ::= sclp nm DOT STAR. {
  pParse->sflag |= SQL_FLAG_EXPR;
}

// An option "AS <id>" phrase that can follow one of the expressions that
// define the result set, or one of the tables in the FROM clause.
//
%type as {Token}
as(X) ::= AS nm(Y).    {X = Y;}
as(X) ::= ids(Y).      {X = Y;}
as(X) ::= .            {X.n = 0;}


%type seltablist {SrcList*}
%destructor seltablist {}
%type stl_prefix {SrcList*}
%destructor stl_prefix {}
%type from {SrcList*}
%destructor from {}

// A complete FROM clause.
//
from(A) ::= .                                 {A = sqliteMalloc(sizeof(*A));}
from(A) ::= FROM seltablist(X).               {A = X;}

// "seltablist" is a "Select Table List" - the content of the FROM clause
// in a SELECT statement.  "stl_prefix" is a prefix of this list.
//
stl_prefix(A) ::= seltablist(X) joinop(Y).    {
   A = X;
   if( A && A->nSrc>0 ) A->a[A->nSrc-1].jointype = Y;
}
stl_prefix(A) ::= .                           {A = 0;}
seltablist ::= stl_prefix nm dbnm as on_opt using_opt. {
  pParse->sflag |= SQL_FLAG_EXPR;
}
%ifndef SQLITE_OMIT_SUBQUERY
  seltablist ::= stl_prefix LP seltablist_paren RP
                    as on_opt using_opt. {
  pParse->sflag |= SQL_FLAG_EXPR;
}
  
  // A seltablist_paren nonterminal represents anything in a FROM that
  // is contained inside parentheses.  This can be either a subquery or
  // a grouping of table and subqueries.
  //
  %type seltablist_paren {Select*}
  %destructor seltablist_paren { }
  seltablist_paren(A) ::= select(S).      {A = S;}
  seltablist_paren ::= seltablist.  {
     pParse->select_num++;
  }
%endif // SQLITE_OMIT_SUBQUERY

%type dbnm {Token}
dbnm(A) ::= .          {A.z=0; A.n=0;}
dbnm(A) ::= DOT nm(X). {A = X;}

%type fullname {SrcList*}
%destructor fullname {}
fullname ::= nm dbnm.  {  pParse->sflag |= SQL_FLAG_LIST; }

%type joinop {int}
%type joinop2 {int}
joinop(X) ::= COMMA|JOIN.              { X = JT_INNER; }
joinop ::= JOIN_KW JOIN.         { pParse->sflag |= SQL_FLAG_JOIN; }
joinop ::= JOIN_KW nm JOIN.   { pParse->sflag |= SQL_FLAG_JOIN; }
joinop ::= JOIN_KW nm nm JOIN.
                                       { pParse->sflag |= SQL_FLAG_JOIN; }

%type on_opt {Expr*}
%destructor on_opt { }
on_opt(N) ::= ON expr(E).   {N = E;}
on_opt(N) ::= .             {N = 0;}

%type using_opt {IdList*}
%destructor using_opt { }
using_opt(U) ::= USING LP inscollist(L) RP.  {U = L;}
using_opt(U) ::= .                        {U = 0;}


%type orderby_opt {ExprList*}
%destructor orderby_opt { }
%type sortlist {ExprList*}
%destructor sortlist { }
%type sortitem {Expr*}
%destructor sortitem { }

orderby_opt(A) ::= .                          {A = 0;}
orderby_opt(A) ::= ORDER BY sortlist(X).      {A = X;}
sortlist ::= sortlist COMMA sortitem collate sortorder. {
	pParse->sflag |= SQL_FLAG_EXPR;
}
sortlist ::= sortitem collate sortorder. {
	pParse->sflag |= SQL_FLAG_EXPR;
}
sortitem(A) ::= expr(X).   {A = X;}

%type sortorder {int}
%type collate {Token}

sortorder(A) ::= ASC.           {A = SQLITE_SO_ASC;}
sortorder(A) ::= DESC.          {A = SQLITE_SO_DESC;}
sortorder(A) ::= .              {A = SQLITE_SO_ASC;}
collate(C) ::= .                {C.z = 0; C.n = 0;}
collate(C) ::= COLLATE id(X).   {C = X;}

%type groupby_opt {ExprList*}
%destructor groupby_opt { }
groupby_opt(A) ::= .                      {A = 0;}
groupby_opt(A) ::= GROUP BY exprlist(X).  {A = X;}

%type having_opt {Expr*}
%destructor having_opt {}
having_opt(A) ::= .                {A = 0;}
having_opt(A) ::= HAVING expr(X).  {A = X;}

%type limit_opt {struct LimitVal}
%destructor limit_opt {
}
limit_opt(A) ::= .                     {A.pLimit = 0; A.pOffset = 0;}
limit_opt(A) ::= LIMIT expr(X).        {A.pLimit = X; A.pOffset = 0;}
limit_opt(A) ::= LIMIT expr(X) OFFSET expr(Y). 
                                       {A.pLimit = X; A.pOffset = Y;}
limit_opt(A) ::= LIMIT expr(X) COMMA expr(Y). 
                                       {A.pOffset = X; A.pLimit = Y;}

/////////////////////////// The DELETE statement /////////////////////////////
//
cmd ::= DELETE FROM fullname where_opt limit_opt. {pParse->sflag |= SQL_FLAG_DELETE;}

%type where_opt {Expr*}
%destructor where_opt { }

where_opt(A) ::= .                    {A = 0;}
where_opt(A) ::= WHERE expr(X).       {A = X;}

////////////////////////// The UPDATE command ////////////////////////////////
//
//cmd ::= UPDATE orconf(R) fullname(X) SET setlist(Y) where_opt(Z).
cmd ::= UPDATE fullname SET setlist where_opt limit_opt.
    {pParse->sflag |= SQL_FLAG_UPDATE;}

%type setlist {ExprList*}
%destructor setlist { }

setlist ::= setlist COMMA nm EQ expr.
    {pParse->sflag |= SQL_FLAG_EXPR;}
setlist ::= nm EQ expr.   {pParse->sflag |= SQL_FLAG_EXPR;}

////////////////////////// The INSERT command /////////////////////////////////
//
/* cmd ::= insert_cmd(R) INTO fullname(X) inscollist_opt(F) */ 
/*         VALUES LP itemlist(Y) RP. */
/*             {sqlite3Insert(pParse, X, Y, 0, F, R);} */
cmd ::= insert_cmd INTO fullname inscollist_opt 
        VALUES valueslist.
            {pParse->sflag |= SQL_FLAG_INSERT;}

cmd ::= insert_cmd INTO fullname inscollist_opt
        SET setlist. 
            {pParse->sflag |= SQL_FLAG_INSERT;}

cmd ::= insert_cmd fullname inscollist_opt
        SET setlist. 
            {pParse->sflag |= SQL_FLAG_INSERT;}

cmd ::= insert_cmd INTO fullname inscollist_opt select.
            {pParse->sflag |= SQL_FLAG_INSERT;}

%type insert_cmd {int}
//insert_cmd(A) ::= INSERT orconf(R).   {A = R;}
insert_cmd(A) ::= INSERT. { A = OE_Default; }
insert_cmd(A) ::= REPLACE.            {A = OE_Replace;}

%type valueslist {ValuesList*}
%destructor valueslist { }

valueslist ::= valueslist COMMA LP itemlist RP.   { pParse->sflag |= SQL_FLAG_EXPR; }
valueslist ::= LP itemlist RP.                       { pParse->sflag |= SQL_FLAG_EXPR; }
valueslist(VL) ::= LP RP.                                   { VL = 0; }

%type itemlist {ExprList*}
%destructor itemlist { }

itemlist ::= itemlist COMMA expr.  {pParse->sflag |= SQL_FLAG_EXPR;}
itemlist ::= expr.                    {pParse->sflag |= SQL_FLAG_EXPR;}

%type inscollist_opt {IdList*}
%destructor inscollist_opt {}
%type inscollist {IdList*}
%destructor inscollist {}

inscollist_opt(A) ::= .                       {A = 0;}
inscollist_opt(A) ::= LP RP.                  {A = 0;}
inscollist_opt(A) ::= LP inscollist(X) RP.    {A = X;}
inscollist ::= inscollist COMMA nm.  { pParse->sflag |= SQL_FLAG_LIST;}
inscollist ::= nm.                      { pParse->sflag |= SQL_FLAG_LIST;}
                           
/////////////////////////// Expression Processing /////////////////////////////
//

%type expr {Expr*}
%destructor expr {}
%type term {Expr*}
%destructor term {}

expr(A) ::= term(X).             {A = X;}
expr ::= LP expr RP. {pParse->sflag |= SQL_FLAG_EXPR;}
term ::= NULL.             {pParse->sflag |= SQL_FLAG_EXPR;}
expr ::= ID.               {pParse->sflag |= SQL_FLAG_EXPR;}
expr ::= JOIN_KW.          {pParse->sflag |= SQL_FLAG_EXPR;}
expr ::= nm DOT nm. {
	pParse->sflag |= SQL_FLAG_EXPR;
}
expr ::= nm DOT nm DOT nm. {
	pParse->sflag |= SQL_FLAG_EXPR;
}
term ::= INTEGER|FLOAT|BLOB.      {pParse->sflag |= SQL_FLAG_EXPR;}
term ::= STRING.       {pParse->sflag |= SQL_FLAG_EXPR;}
expr ::= REGISTER.     {pParse->sflag |= SQL_FLAG_EXPR;}
expr ::= VARIABLE.     {
	pParse->sflag |= SQL_FLAG_EXPR;
}
expr ::= VARIABLE1.     {
	pParse->sflag |= SQL_FLAG_EXPR;
}
%ifndef SQLITE_OMIT_CAST
expr ::= CAST LP expr AS typetoken RP. {
	pParse->sflag |= SQL_FLAG_EXPR;
}
%endif // SQLITE_OMIT_CAST
expr ::= ID LP distinct exprlist RP. {
	pParse->sflag |= SQL_FLAG_EXPR;
}
expr ::= ID LP STAR RP. {
	pParse->sflag |= SQL_FLAG_EXPR;
}
term ::= CTIME_KW. {
  /* The CURRENT_TIME, CURRENT_DATE, and CURRENT_TIMESTAMP values are
  ** treated as functions that return constants */
	pParse->sflag |= SQL_FLAG_EXPR;
}
expr ::= expr AND expr.            {pParse->sflag |= SQL_FLAG_OPT;}
expr ::= expr OR expr.             {pParse->sflag |= SQL_FLAG_OPT;}
expr ::= expr LT|GT|GE|LE expr.    {pParse->sflag |= SQL_FLAG_OPT;}
expr ::= expr EQ expr.          {pParse->sflag |= SQL_FLAG_EXPR;}
expr ::= expr NE expr.          {pParse->sflag |= SQL_FLAG_OPT;}
expr ::= expr BITAND|BITOR|LSHIFT|RSHIFT expr.
                                                {pParse->sflag |= SQL_FLAG_OPT;}
expr ::= expr PLUS|MINUS expr.     {pParse->sflag |= SQL_FLAG_OPT;}
expr ::= expr STAR|SLASH|REM expr. {pParse->sflag |= SQL_FLAG_OPT;}
expr ::= expr CONCAT expr.         {pParse->sflag |= SQL_FLAG_OPT;}
%type likeop {struct LikeOp}
likeop(A) ::= LIKE_KW(X).     {A.eOperator = X; A.not = 0;}
likeop(A) ::= NOT LIKE_KW(X). {A.eOperator = X; A.not = 1;}
%type escape {Expr*}
%destructor escape {}
escape(X) ::= ESCAPE expr(A). [ESCAPE] {X = A;}
escape(X) ::= .               [ESCAPE] {X = 0;}
expr ::= expr likeop expr escape.  [LIKE_KW]  {
	pParse->sflag |= SQL_FLAG_EXPR;
}

expr ::= expr ISNULL|NOTNULL. {
	pParse->sflag |= SQL_FLAG_EXPR;
}
expr ::= expr IS NULL. {
	pParse->sflag |= SQL_FLAG_EXPR;
}
expr ::= expr NOT NULL. {
	pParse->sflag |= SQL_FLAG_EXPR;
}
expr ::= expr IS NOT NULL. {
	pParse->sflag |= SQL_FLAG_EXPR;
}
expr ::= NOT|BITNOT expr. {
	pParse->sflag |= SQL_FLAG_EXPR;
}
expr ::= MINUS expr. [UMINUS] {
	pParse->sflag |= SQL_FLAG_EXPR;
}
expr ::= PLUS expr. [UPLUS] {
	pParse->sflag |= SQL_FLAG_EXPR;
}
%type between_op {int}
between_op(A) ::= BETWEEN.     {A = 0;}
between_op(A) ::= NOT BETWEEN. {A = 1;}

%type between_elem {Expr*}
%destructor between_elem {}

between_elem ::= INTEGER|STRING. {pParse->sflag |= SQL_FLAG_EXPR;}

//expr(A) ::= expr(W) between_op(N) expr(X) AND expr(Y). [BETWEEN] {
expr ::= expr between_op between_elem AND between_elem. [BETWEEN] {
	pParse->sflag |= SQL_FLAG_EXPR;
}
%ifndef SQLITE_OMIT_SUBQUERY
  %type in_op {int}
  in_op(A) ::= IN.      {A = 0;}
  in_op(A) ::= NOT IN.  {A = 1;}
  expr ::= expr in_op LP exprlist RP. [IN] {
	  pParse->sflag |= SQL_FLAG_EXPR;
  }
  expr ::= LP select RP. {
	  pParse->sflag |= SQL_FLAG_EXPR;
  }
  expr ::= expr in_op LP select RP.  [IN] {
	  pParse->sflag |= SQL_FLAG_EXPR;
  }
  expr ::= expr in_op nm dbnm. [IN] {
	  pParse->sflag |= SQL_FLAG_EXPR;
  }
  expr ::= EXISTS LP select RP. {
	  pParse->sflag |= SQL_FLAG_EXPR;
  }
%endif // SQLITE_OMIT_SUBQUERY

/* CASE expressions */
expr ::= CASE case_operand case_exprlist case_else END. {
  pParse->sflag |= SQL_FLAG_EXPR;
}
%type case_exprlist {ExprList*}
%destructor case_exprlist { }
case_exprlist ::= case_exprlist WHEN expr THEN expr. {
  pParse->sflag |= SQL_FLAG_EXPR;
}
case_exprlist ::= WHEN expr THEN expr. {
  pParse->sflag |= SQL_FLAG_EXPR;
}
%type case_else {Expr*}
%destructor case_else {}
case_else(A) ::=  ELSE expr(X).         {A = X;}
case_else(A) ::=  .                     {A = 0;} 
%type case_operand {Expr*}
%destructor case_operand {}
case_operand(A) ::= expr(X).            {A = X;} 
case_operand(A) ::= .                   {A = 0;} 

%type exprlist {ExprList*}
%destructor exprlist { }
%type expritem {Expr*}
%destructor expritem { }

exprlist ::= exprlist COMMA expritem. 
                                        {pParse->sflag |= SQL_FLAG_EXPR;}
exprlist ::= expritem.            {pParse->sflag |= SQL_FLAG_EXPR;}
expritem(A) ::= expr(X).                {A = X;}
expritem(A) ::= .                       {A = 0;}

///////////////////////////// The CREATE INDEX command ///////////////////////
//
//cmd ::= CREATE(S) uniqueflag(U) INDEX ifnotexists(NE) nm(X) dbnm(D)
//        ON nm(Y) LP idxlist(Z) RP(E). {
//  sqlite3CreateIndex(pParse, &X, &D, sqlite3SrcListAppend(0,&Y,0), Z, U,
//                      &S, &E, SQLITE_SO_ASC, NE);
//}

//%type uniqueflag {int}
//uniqueflag(A) ::= UNIQUE.  {A = OE_Abort;}
//uniqueflag(A) ::= .        {A = OE_None;}

%type idxlist {ExprList*}
%destructor idxlist { }
%type idxlist_opt {ExprList*}
%destructor idxlist_opt {}
%type idxitem {Token}

idxlist_opt(A) ::= .                         {A = 0;}
idxlist_opt(A) ::= LP idxlist(X) RP.         {A = X;}
idxlist ::= idxlist COMMA idxitem collate sortorder.  {
	pParse->sflag |= SQL_FLAG_EXPR;
}
idxlist ::= idxitem collate sortorder. {
	pParse->sflag |= SQL_FLAG_EXPR;
}
idxitem(A) ::= nm(X).              {A = X;}


///////////////////////////// The DROP INDEX command /////////////////////////
//
//cmd ::= DROP INDEX ifexists(E) fullname(X).   {sqlite3DropIndex(pParse, X, E);}

///////////////////////////// The VACUUM command /////////////////////////////
//
//cmd ::= VACUUM.                {sqlite3Vacuum(pParse);}
//cmd ::= VACUUM nm.             {sqlite3Vacuum(pParse);}

///////////////////////////// The PRAGMA command /////////////////////////////
//
%ifndef SQLITE_OMIT_PRAGMA
//cmd ::= PRAGMA nm(X) dbnm(Z) EQ nm(Y).  {sqlite3Pragma(pParse,&X,&Z,&Y,0);}
//cmd ::= PRAGMA nm(X) dbnm(Z) EQ ON(Y).  {sqlite3Pragma(pParse,&X,&Z,&Y,0);}
//cmd ::= PRAGMA nm(X) dbnm(Z) EQ plus_num(Y). {sqlite3Pragma(pParse,&X,&Z,&Y,0);}
//cmd ::= PRAGMA nm(X) dbnm(Z) EQ minus_num(Y). {
//  sqlite3Pragma(pParse,&X,&Z,&Y,1);
//}
//cmd ::= PRAGMA nm(X) dbnm(Z) LP nm(Y) RP. {sqlite3Pragma(pParse,&X,&Z,&Y,0);}
//cmd ::= PRAGMA nm(X) dbnm(Z).             {sqlite3Pragma(pParse,&X,&Z,0,0);}
%endif // SQLITE_OMIT_PRAGMA
plus_num(A) ::= plus_opt number(X).   {A = X;}
minus_num(A) ::= MINUS number(X).     {A = X;}
number(A) ::= INTEGER|FLOAT(X).       {A = X;}
plus_opt ::= PLUS.
plus_opt ::= .

//////////////////////////// The CREATE TRIGGER command /////////////////////

%ifndef SQLITE_OMIT_TRIGGER

/* cmd ::= CREATE trigger_decl(A) BEGIN trigger_cmd_list(S) END(Z). { */
/*   Token all; */
/*   all.z = A.z; */
/*   all.n = (Z.z - A.z) + Z.n; */
/*   sqlite3FinishTrigger(pParse, S, &all); */
/* } */

/* trigger_decl(A) ::= temp(T) TRIGGER nm(B) dbnm(Z) trigger_time(C) */
/*                     trigger_event(D) */
/*                     ON fullname(E) foreach_clase(F) when_clause(G). { */
/*   sqlite3BeginTrigger(pParse, &B, &Z, C, D.a, D.b, E, F, G, T); */
/*   A = (Z.n==0?B:Z); */
/* } */

/* %type trigger_time  {int} */
/* trigger_time(A) ::= BEFORE.      { A = TK_BEFORE; } */
/* trigger_time(A) ::= AFTER.       { A = TK_AFTER;  } */
/* trigger_time(A) ::= INSTEAD OF.  { A = TK_INSTEAD;} */
/* trigger_time(A) ::= .            { A = TK_BEFORE; } */

/* %type trigger_event {struct TrigEvent} */
/* %destructor trigger_event {sqlite3IdListDelete($$.b);} */
/* trigger_event(A) ::= DELETE|INSERT(OP).       {A.a = @OP; A.b = 0;} */
/* trigger_event(A) ::= UPDATE(OP).              {A.a = @OP; A.b = 0;} */
/* trigger_event(A) ::= UPDATE OF inscollist(X). {A.a = TK_UPDATE; A.b = X;} */

/* %type foreach_clause {int} */
/* foreach_clause(A) ::= .                   { A = TK_ROW; } */
/* foreach_clause(A) ::= FOR EACH ROW.       { A = TK_ROW; } */
/* foreach_clause(A) ::= FOR EACH STATEMENT. { A = TK_STATEMENT; } */

/* %type when_clause {Expr*} */
/* %destructor when_clause {sqlite3ExprDelete($$);} */
/* when_clause(A) ::= .             { A = 0; } */
/* when_clause(A) ::= WHEN expr(X). { A = X; } */

/* %type trigger_cmd_list {TriggerStep*} */
/* %destructor trigger_cmd_list {sqlite3DeleteTriggerStep($$);} */
/* trigger_cmd_list(A) ::= trigger_cmd_list(Y) trigger_cmd(X) SEMI. { */
/*   if( Y ){ */
/*     Y->pLast->pNext = X; */
/*   }else{ */
/*     Y = X; */
/*   } */
/*   Y->pLast = X; */
/*   A = Y; */
/* } */
/* trigger_cmd_list(A) ::= . { A = 0; } */

/* %type trigger_cmd {TriggerStep*} */
/* %destructor trigger_cmd {sqlite3DeleteTriggerStep($$);} */
/* // UPDATE */ 
/* trigger_cmd(A) ::= UPDATE orconf(R) nm(X) SET setlist(Y) where_opt(Z). */  
/*                { A = sqlite3TriggerUpdateStep(&X, Y, Z, R); } */

/* // INSERT */
/* trigger_cmd(A) ::= insert_cmd(R) INTO nm(X) inscollist_opt(F) */ 
/*                    VALUES LP itemlist(Y) RP. */  
/*                {A = sqlite3TriggerInsertStep(&X, F, Y, 0, R);} */

/* trigger_cmd(A) ::= insert_cmd(R) INTO nm(X) inscollist_opt(F) select(S). */
/*                {A = sqlite3TriggerInsertStep(&X, F, 0, S, R);} */

/* // DELETE */
/* trigger_cmd(A) ::= DELETE FROM nm(X) where_opt(Y). */
/*                {A = sqlite3TriggerDeleteStep(&X, Y);} */

/* // SELECT */
/* trigger_cmd(A) ::= select(X).  {A = sqlite3TriggerSelectStep(X); } */

/* // The special RAISE expression that may occur in trigger programs */
/* expr(A) ::= RAISE(X) LP IGNORE RP(Y).  { */
/*   A = sqlite3Expr(TK_RAISE, 0, 0, 0); */ 
/*   if( A ){ */
/*     A->iColumn = OE_Ignore; */
/*     sqlite3ExprSpan(A, &X, &Y); */
/*   } */
/* } */
/* expr(A) ::= RAISE(X) LP raisetype(T) COMMA nm(Z) RP(Y).  { */
/*   A = sqlite3Expr(TK_RAISE, 0, 0, &Z); */ 
/*   if( A ) { */
/*     A->iColumn = T; */
/*     sqlite3ExprSpan(A, &X, &Y); */
/*   } */
/* } */
%endif // !SQLITE_OMIT_TRIGGER

%type raisetype {int}
raisetype(A) ::= ROLLBACK.  {A = OE_Rollback;}
raisetype(A) ::= ABORT.     {A = OE_Abort;}
raisetype(A) ::= FAIL.      {A = OE_Fail;}


////////////////////////  DROP TRIGGER statement //////////////////////////////
%ifndef SQLITE_OMIT_TRIGGER
/* cmd ::= DROP TRIGGER fullname(X). { */
/*   sqlite3DropTrigger(pParse,X); */
/* } */
%endif // !SQLITE_OMIT_TRIGGER

//////////////////////// ATTACH DATABASE file AS name /////////////////////////
//cmd ::= ATTACH database_kw_opt expr(F) AS expr(D) key_opt(K). {
//  sqlite3Attach(pParse, F, D, K);
//}
//%type key_opt {Expr *}
//%destructor key_opt {sqlite3ExprDelete($$);}
//key_opt(A) ::= .                     { A = 0; }
//key_opt(A) ::= KEY expr(X).          { A = X; }

//database_kw_opt ::= DATABASE.
//database_kw_opt ::= .

//////////////////////// DETACH DATABASE name /////////////////////////////////
//cmd ::= DETACH database_kw_opt expr(D). {
//  sqlite3Detach(pParse, D);
//}

////////////////////////// REINDEX collation //////////////////////////////////
%ifndef SQLITE_OMIT_REINDEX
//cmd ::= REINDEX.                {sqlite3Reindex(pParse, 0, 0);}
//cmd ::= REINDEX nm(X) dbnm(Y).  {sqlite3Reindex(pParse, &X, &Y);}
%endif

/////////////////////////////////// ANALYZE ///////////////////////////////////
%ifndef SQLITE_OMIT_ANALYZE
//cmd ::= ANALYZE.                {sqlite3Analyze(pParse, 0, 0);}
//cmd ::= ANALYZE nm(X) dbnm(Y).  {sqlite3Analyze(pParse, &X, &Y);}
%endif

//////////////////////// ALTER TABLE table ... ////////////////////////////////
%ifndef SQLITE_OMIT_ALTERTABLE
/* cmd ::= ALTER TABLE fullname(X) RENAME TO nm(Z). { */
/*   sqlite3AlterRenameTable(pParse,X,&Z); */
/* } */
/* cmd ::= ALTER TABLE add_column_fullname ADD kwcolumn_opt column(Y). { */
/*   sqlite3AlterFinishAddColumn(pParse, &Y); */
/* } */
/* add_column_fullname ::= fullname(X). { */
/*   sqlite3AlterBeginAddColumn(pParse, X); */
/* } */
/* kwcolumn_opt ::= . */
/* kwcolumn_opt ::= COLUMNKW. */
%endif


//////////////////////// the SET statement ////////////////////////////////
cmd ::= SET variable_assignment_list. {
	  pParse->sflag |= SQL_FLAG_STMT;
}

cmd ::= SET NAMES ids.  {
	  pParse->sflag |= SQL_FLAG_STMT;
}

cmd ::= SET CHARACTER SET ids. {
	  pParse->sflag |= SQL_FLAG_STMT;
}

%type variable_assignment_list {ExprList*}
%destructor variable_assignment_list { }
variable_assignment_list ::= variable_assignment_list COMMA scope_qualifier user_var_name EQ expr. {
	  pParse->sflag |= SQL_FLAG_EXPR;
}

variable_assignment_list ::= scope_qualifier user_var_name EQ expr. {
	  pParse->sflag |= SQL_FLAG_EXPR;
}

// @@global or @@session or @@local
scope_qualifier ::= GLOBAL. 
scope_qualifier ::= LOCAL. 
scope_qualifier ::= SESSION. 
scope_qualifier ::= VARIABLE1 DOT. { pParse->sflag |= SQL_FLAG_SCOPE; }
scope_qualifier ::= .

%type user_var_name {Token}
user_var_name(A) ::= ids(V). { A = V; }
user_var_name(A) ::= VARIABLE(V). { A = V; }

/////////////////// the SHOW statement /////////////////////////
cmd ::= show_databes.
cmd ::= show_tables.
cmd ::= show_table_status.
cmd ::= show_variables.
cmd ::= show_collation.

show_databes ::= SHOW DATABASES|SCHEMAS show_statement_pattern. {
		pParse->sflag |= SQL_FLAG_SHOW;
}

show_tables ::= SHOW full_keyword TABLES from_db show_statement_pattern. {
		pParse->sflag |= SQL_FLAG_SHOW;
}

show_table_status ::= SHOW TABLE STATUS from_db show_statement_pattern. {
		pParse->sflag |= SQL_FLAG_SHOW;
}

show_variables ::= SHOW scope_qualifier VARIABLES show_statement_pattern. {
		pParse->sflag |= SQL_FLAG_SHOW;
}

show_collation ::= SHOW COLLATION show_statement_pattern. {
		pParse->sflag |= SQL_FLAG_SHOW;
}

full_keyword ::= JOIN_KW.
full_keyword ::= .

show_statement_pattern ::= LIKE_KW STRING|ID.
show_statement_pattern ::= where_opt. {
}

from_db ::= .
from_db ::= FROM|IN nm.

