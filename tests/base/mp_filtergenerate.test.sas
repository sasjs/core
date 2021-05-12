/**
  @file
  @brief Testing mp_filtergenerate macro

  <h4> SAS Macros </h4>
  @li mp_filtergenerate.sas
  @li mp_filtercheck.sas
  @li mp_assertdsobs.sas

**/

options source2;

/* valid filter */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,AGE,>,5
AND,AND,1,SEX,NE,"'M'"
AND,OR,2,Name,NOT IN,"('Jane','Janet')"
AND,OR,2,Weight,>=,84.6
;;;;
run;
%mp_filtercheck(work.inds,targetds=sashelp.class)
%mp_filtergenerate(work.inds,outref=myfilter)
data work.test;
  set sashelp.class;
  where %inc myfilter;;
run;
%mp_assertdsobs(work.test,
  desc=Valid filter,
  test=EQUALS 8,
  outds=work.test_results
)

/* empty filter (return all records) */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
;;;;
run;
%mp_filtercheck(work.inds,targetds=sashelp.class)
%mp_filtergenerate(work.inds,outref=myfilter)
data work.test;
  set sashelp.class;
  where %inc myfilter;;
run;
%mp_assertdsobs(work.test,
  desc=Empty filter (return all records) ,
  test=EQUALS 19,
  outds=work.test_results
)

/* single line filter */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,OR,2,Name,IN,"('Jane','Janet')"
;;;;
run;
%mp_filtercheck(work.inds,targetds=sashelp.class)
%mp_filtergenerate(work.inds,outref=myfilter)
data work.test;
  set sashelp.class;
  where %inc myfilter;;
run;
%mp_assertdsobs(work.test,
  desc=Single line filter ,
  test=EQUALS 2,
  outds=work.test_results
)

/* single line 2 group filter */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
OR,OR,2,Name,IN,"('Jane','Janet')"
OR,OR,3,Name,IN,"('James')"
;;;;
run;
%mp_filtercheck(work.inds,targetds=sashelp.class)
%mp_filtergenerate(work.inds,outref=myfilter)
data work.test;
  set sashelp.class;
  where %inc myfilter;;
run;
%mp_assertdsobs(work.test,
  desc=Single line 2 group filter ,
  test=EQUALS 3,
  outds=work.test_results
)

/* filter with nothing returned */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,OR,2,Name,IN,"('Jane','Janet')"
AND,OR,3,Name,IN,"('James')"
;;;;
run;
%mp_filtercheck(work.inds,targetds=sashelp.class)
%mp_filtergenerate(work.inds,outref=myfilter)
data work.test;
  set sashelp.class;
  where %inc myfilter;;
run;
%mp_assertdsobs(work.test,
  desc=Filter with nothing returned,
  test=EQUALS 0,
  outds=work.test_results
)

