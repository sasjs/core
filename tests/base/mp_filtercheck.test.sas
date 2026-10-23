/**
  @file
  @brief Testing mp_filtercheck macro

  <h4> SAS Macros </h4>
  @li mp_filtercheck.sas
  @li mp_assertdsobs.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

/* set up test data */
data work.class ;
length name $8 sex $1 age height weight 8;
infile cards dsd;
input Name:$char. Sex :$char. Age Height Weight;
datalines4;
Alfred,M,14,69,112.5
Alice,F,13,56.5,84
Barbara,F,13,65.3,98
Carol,F,14,62.8,102.5
Henry,M,14,63.5,102.5
James,M,12,57.3,83
Jane,F,12,59.8,84.5
Janet,F,15,62.5,112.5
Jeffrey,M,13,62.5,84
John,M,12,59,99.5
Joyce,F,11,51.3,50.5
Judy,F,14,64.3,90
Louise,F,12,56.3,77
Mary,F,15,66.5,112
Philip,M,16,72,150
Robert,M,12,64.8,128
Ronald,M,15,67,133
Thomas,M,11,57.5,85
William,M,15,66.5,112
;;;;
run;

/* VALID filter conditions */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,AGE,=,12
AND,AND,1,SEX,<=,"'M'"
AND,OR,2,Name,NOT IN,"('Jane','Alfred')"
AND,OR,2,Weight,>=,77.7
AND,OR,2,Weight,NE,77.7
AND,AND,1,age,=,.A
AND,AND,1,height,<,.B
AND,AND,1,age,IN,"(.a,.b,.)"
AND,AND,1,age,IN,"(.A)"
AND,AND,1,AGE,=,AGE
AND,AND,1,AGE,<,Weight
AND,AND,1,AGE,BETWEEN,"HEIGHT AND WEIGHT"
AND,OR,2,Name,=,name
;;;;
run;

%mp_assertscope(SNAPSHOT)
%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%mp_assertscope(COMPARE)

%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=Valid filter query,
  test=EMPTY,
  outds=work.test_results
)

/* invalid column */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,invalid,=,12
AND,AND,1,SEX,<=,"'M'"
AND,OR,2,Name,NOT IN,"('Jane','Alfred')"
AND,OR,2,Weight,>=,7
;;;;
run;
%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=Invalid column name,
  test=HASOBS,
  outds=work.test_results
)

/* invalid raw value */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,OR,2,Name,NOT IN,"(''''Jane','Alfred')"
;;;;
run;

%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=Invalid raw value,
  test=HASOBS,
  outds=work.test_results
)

/* invalid IN value */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,OR,2,age,IN,"(.,.a,X)"
;;;;
run;

%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=Invalid IN value,
  test=HASOBS,
  outds=work.test_results
)

/* Code injection - column name */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,%abort,=,12
AND,OR,2,Weight,>=,7
;;;;
run;

%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=Code injection - column name,
  test=HASOBS,
  outds=work.test_results
)

/* Code injection - raw values*/
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,age,=,;;%abort
;;;;
run;
%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=Code injection - raw value abort,
  test=HASOBS,
  outds=work.test_results
)

/* Supply variables with incorrect types */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:8.;
datalines4;
AND,AND,1,age,=,0
;;;;
run;
%let syscc=0;
%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%mp_assert(iftrue=(&syscc=42),
  desc=Throw error if RAW_VALUE is incorrect,
  outds=work.test_results
)
%let syscc=0;


/* invalid IN value (cannot use var names) */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,AGE,NOT IN,"(height, age)"
;;;;
run;

%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=Invalid IN syntax,
  test=HASOBS,
  outds=work.test_results
)

/* temporal literals are valid values for numeric columns */
data work.dates;
  length dt dtm tm 8;
  format dt date9. dtm datetime20. tm time8.;
  dt='20APR2042'd;
  dtm='01JAN1960:00:00:42'dt;
  tm='00:00:42't;
run;

data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,dt,=,"'20APR2042'd"
AND,AND,1,dt,NE,"'20APR2042'd"
AND,AND,1,dtm,>=,"'01JAN1960:00:00:42'dt"
AND,AND,1,tm,<,"'00:00:42't"
AND,AND,1,dt,IN,"('20APR2042'd,'21APR2042'd)"
AND,AND,1,dt,BETWEEN,"'20APR2042'd AND '21APR2042'd"
;;;;
run;

%mp_filtercheck(work.inds,
  targetds=work.dates,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=Temporal literals in RAW_VALUE,
  test=EMPTY,
  outds=work.test_results
)

/* a temporal literal is not valid for a character column */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,name,=,"'20APR2042'd"
;;;;
run;

%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=Temporal literal against a character column,
  test=HASOBS,
  outds=work.test_results
)

/* every value of an IN list is checked, not just the first */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,dt,IN,"('20APR2042'd,notanumber)"
;;;;
run;

%mp_filtercheck(work.inds,
  targetds=work.dates,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=Invalid value after the first in an IN list,
  test=HASOBS,
  outds=work.test_results
)

/* a suffix that is not temporal is still rejected */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,dt,=,"'20APR2042'x"
;;;;
run;

%mp_filtercheck(work.inds,
  targetds=work.dates,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=Non temporal literal suffix,
  test=HASOBS,
  outds=work.test_results
)

/* a character IN list is still validated - only a numeric list takes the
  value-by-value path and skips the generic check */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,name,IN,"(Alfred,Alice)"
;;;;;
run;

%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=Character IN list is still validated,
  test=HASOBS,
  outds=work.test_results
)

/* the regex id is a working variable - it must not leak into the output */
%let re_temporal_col=1;
data _null_;
  dsid=open('work.badrecords','i');
  if dsid>0 then do;
    call symputx('re_temporal_col',(varnum(dsid,'RE_TEMPORAL')>0));
    rc=close(dsid);
  end;
run;
%mp_assert(iftrue=(&re_temporal_col=0),
  desc=re_temporal is not in the bad records table,
  outds=work.test_results
)

/* CONTAINS on a character column is valid */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,Name,CONTAINS,"'ar'"
AND,AND,1,SEX,CONTAINS,"'F'"
;;;;;
run;

%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=CONTAINS on a character column,
  test=EMPTY,
  outds=work.test_results
)

/* CONTAINS on a numeric column is rejected before any SQL is generated */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,Age,CONTAINS,"'12'"
;;;;;
run;

%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=CONTAINS on a numeric column,
  test=HASOBS,
  outds=work.test_results
)

/* the rejection names the operator and the offending variable */
%let contains_reason=0;
data _null_;
  set work.badrecords;
  if index(REASON_CD,
    'CONTAINS is only valid for character variables - Age is numeric')>0
    then call symputx('contains_reason',1);
run;
%mp_assert(iftrue=(&contains_reason=1),
  desc=CONTAINS rejection names the variable,
  outds=work.test_results
)

/* a non numeric value on a numeric column is rejected once, with the
  CONTAINS reason - the generic RAW_VALUE check must not overwrite it */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,Age,CONTAINS,abc
;;;;;
run;

%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=CONTAINS numeric rejection emits a single row,
  test=EQUALS 1,
  outds=work.test_results
)

%let contains_single=0;
data _null_;
  set work.badrecords;
  if index(REASON_CD,
    'CONTAINS is only valid for character variables - Age is numeric')>0
    then call symputx('contains_single',1);
run;
%mp_assert(iftrue=(&contains_single=1),
  desc=CONTAINS numeric rejection keeps its reason,
  outds=work.test_results
)

/* a character column with an unquoted numeric value is also rejected - the
  engine refuses a numeric operand however the column is typed */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,Name,CONTAINS,12
;;;;;
run;

%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=CONTAINS with an unquoted numeric value,
  test=HASOBS,
  outds=work.test_results
)

%let contains_operand=0;
data _null_;
  set work.badrecords;
  if index(REASON_CD,
    'CONTAINS requires a quoted value or a character variable - 12 is neither')
    >0 then call symputx('contains_operand',1);
run;
%mp_assert(iftrue=(&contains_operand=1),
  desc=CONTAINS operand rejection names the value,
  outds=work.test_results
)

/* a character variable is a valid CONTAINS operand */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,Name,CONTAINS,SEX
;;;;;
run;

%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=CONTAINS with a character variable operand,
  test=EMPTY,
  outds=work.test_results
)

/* a quoted value with leading blanks is still a quoted value */
data work.inds;
  length GROUP_LOGIC $3 SUBGROUP_LOGIC $3 SUBGROUP_ID 8 VARIABLE_NM $32
    OPERATOR_NM $10 RAW_VALUE $4000;
  GROUP_LOGIC='AND';
  SUBGROUP_LOGIC='AND';
  SUBGROUP_ID=1;
  VARIABLE_NM='Name';
  OPERATOR_NM='CONTAINS';
  RAW_VALUE=" 'ar'";
run;

%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=CONTAINS with a leading blank before the quote,
  test=EMPTY,
  outds=work.test_results
)

/* a numeric variable operand is a type mismatch, not a missing variable */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,Name,CONTAINS,Age
;;;;;
run;

%mp_filtercheck(work.inds,
  targetds=work.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%let operand_type_reason=0;
data _null_;
  set work.badrecords;
  if index(REASON_CD,'Compared Type (N) is not (C)')>0
    then call symputx('operand_type_reason',1);
run;
%mp_assert(iftrue=(&operand_type_reason=1),
  desc=CONTAINS with a numeric variable operand,
  outds=work.test_results
)

