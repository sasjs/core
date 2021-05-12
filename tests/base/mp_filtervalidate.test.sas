/**
  @file
  @brief Testing mp_filtervalidate macro

  <h4> SAS Macros </h4>
  @li mp_filtergenerate.sas
  @li mp_filtervalidate.sas
  @li mp_assertdsobs.sas

**/


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
%mp_filtergenerate(work.inds,outref=myfilter)
%mp_filtervalidate(myfilter,sashelp.class,outds=work.results,abort=NO)
%mp_assertdsobs(work.results,
  desc=Valid filter,
  test=EMPTY,
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
%mp_filtergenerate(work.inds,outref=myfilter)
%mp_filtervalidate(myfilter,sashelp.class,outds=work.results,abort=NO)
%mp_assertdsobs(work.results,
  desc=Valid filter,
  test=EMPTY,
  outds=work.test_results
)



/* invalid filter*/
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,SEX,NE,2
;;;;
run;
%mp_filtergenerate(work.inds,outref=myfilter)
%mp_filtervalidate(myfilter,sashelp.class,outds=work.results,abort=NO)
%let syscc=0;
%mp_assertdsobs(work.results,
  desc=Valid filter,
  test=EQUALS 1,
  outds=work.test_results
)

