/**
  @file
  @brief Testing mp_filtervalidate macro

  <h4> SAS Macros </h4>
  @li mp_filtergenerate.sas
  @li mp_filtervalidate.sas
  @li mp_assertdsobs.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

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
AND,AND,3,age,=,.a
AND,AND,4,weight,NE,._
;;;;
run;
%mp_filtergenerate(work.inds,outref=myfilter)

%mp_assertscope(SNAPSHOT)
%mp_filtervalidate(myfilter,work.class,outds=work.results,abort=NO)
%mp_assertscope(COMPARE)

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
%mp_filtervalidate(myfilter,work.class,outds=work.results,abort=NO)
%mp_assertdsobs(work.results,
  desc=Empty filter,
  test=EMPTY,
  outds=work.test_results
)



/* invalid filter - char var, num val */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,SEX,NE,2
;;;;
run;
%mp_filtergenerate(work.inds,outref=myfilter)
%mp_filtervalidate(myfilter,work.class,outds=work.results,abort=NO)
%let syscc=0;
%let test3=0;
data _null_;
  set work.results;
  if REASON_CD=:'VALIDATION_ERROR' then call symputx('test3',1);
  putlog (_all_)(=);
  stop;
run;
%mp_assert(
  iftrue=(&test3=1),
  desc=Checking char var could not receive num val,
  outds=work.test_results
)

/* invalid filter - num var, char val */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$10. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,age,NE,"'M'"
;;;;
run;
%mp_filtergenerate(work.inds,outref=myfilter)
%mp_filtervalidate(myfilter,work.class,outds=work.results,abort=NO)
%let syscc=0;
%let test4=0;
data _null_;
  set work.results;
  if REASON_CD=:'VALIDATION_ERROR' then call symputx('test4',1);
  putlog (_all_)(=);
  stop;
run;
%mp_assert(
  iftrue=(&test4=1),
  desc=Checking num var could not receive char val,
  outds=work.test_results
)