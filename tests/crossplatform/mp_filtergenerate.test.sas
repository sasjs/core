/**
  @file
  @brief Testing mp_filtergenerate macro

  <h4> SAS Macros </h4>
  @li mp_filtergenerate.sas
  @li mp_filtercheck.sas
  @li mp_assertdsobs.sas

**/

options source2;

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
%mp_filtercheck(work.inds,targetds=work.class)
%mp_filtergenerate(work.inds,outref=myfilter)
data work.test;
  set work.class;
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
%mp_filtercheck(work.inds,targetds=work.class)
%mp_filtergenerate(work.inds,outref=myfilter)
data work.test;
  set work.class;
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
%mp_filtercheck(work.inds,targetds=work.class)
%mp_filtergenerate(work.inds,outref=myfilter)
data work.test;
  set work.class;
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
%mp_filtercheck(work.inds,targetds=work.class)
%mp_filtergenerate(work.inds,outref=myfilter)
data work.test;
  set work.class;
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
%mp_filtercheck(work.inds,targetds=work.class)
%mp_filtergenerate(work.inds,outref=myfilter)
data work.test;
  set work.class;
  where %inc myfilter;;
run;
%mp_assertdsobs(work.test,
  desc=Filter with nothing returned,
  test=EQUALS 0,
  outds=work.test_results
)

