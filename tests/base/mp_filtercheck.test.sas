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
