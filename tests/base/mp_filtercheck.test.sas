/**
  @file
  @brief Testing mp_filtercheck macro

  <h4> SAS Macros </h4>
  @li mp_filtercheck.sas
  @li mp_assertdsobs.sas

**/


/* valid filter */
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
;;;;
run;

%mp_filtercheck(work.inds,
  targetds=sashelp.class,
  outds=work.badrecords,
  abort=NO
)
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
  targetds=sashelp.class,
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
  targetds=sashelp.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=Invalid raw value,
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
  targetds=sashelp.class,
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
  targetds=sashelp.class,
  outds=work.badrecords,
  abort=NO
)
%let syscc=0;
%mp_assertdsobs(work.badrecords,
  desc=Code injection - raw value abort,
  test=HASOBS,
  outds=work.test_results
)

