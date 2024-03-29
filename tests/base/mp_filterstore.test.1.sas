/**
  @file
  @brief Testing mp_filterstore macro

  <h4> SAS Macros </h4>
  @li mp_coretable.sas
  @li mp_filterstore.sas
  @li mp_assertdsobs.sas
  @li mp_assert.sas

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

libname permlib (work);

%mp_coretable(LOCKTABLE,libds=permlib.locktable)
%mp_coretable(FILTER_SUMMARY,libds=permlib.filtsum)
%mp_coretable(FILTER_DETAIL,libds=permlib.filtdet)
%mp_coretable(MAXKEYTABLE,libds=permlib.maxkey)

/* valid filter */
data work.inds;
  infile datalines4 dsd;
  input GROUP_LOGIC:$3. SUBGROUP_LOGIC:$3. SUBGROUP_ID:8. VARIABLE_NM:$32.
    OPERATOR_NM:$12. RAW_VALUE:$4000.;
datalines4;
AND,AND,1,AGE,=,12
AND,AND,1,SEX,<=,"'M'"
AND,OR,2,Name,NOT IN,"('Jane','Alfred')"
AND,OR,2,Weight,>=,77.7
AND,OR,2,Weight,NE,77.7
AND,AND,3,age,NOT IN,"(.a,.b,.)"
AND,AND,3,age,NOT IN,"(.A)"
AND,AND,4,Name,=,"'Jeremiah'"
;;;;
run;

%mp_filterstore(libds=work.class,
  queryds=work.inds,
  filter_summary=permlib.filtsum,
  filter_detail=permlib.filtdet,
  lock_table=permlib.locktable,
  maxkeytable=permlib.maxkey,
  outresult=work.result,
  outquery=work.query,
  mdebug=1
)
%mp_assert(iftrue=(&syscc=0),
  desc=Ensure macro runs without errors,
  outds=work.test_results
)
/* ensure only one record created */
%mp_assertdsobs(permlib.filtsum,
  desc=Initial query,
  test=ATMOST 1,
  outds=work.test_results
)
/* check RK is correct */
proc sql noprint;
select max(filter_rk) into: test1 from work.result;
%mp_assert(iftrue=(&test1=1),
  desc=Ensure filter rk is correct,
  outds=work.test_results
)

/* Test 2 - load same table again and ensure we get the same RK */
%mp_filterstore(libds=work.class,
  queryds=work.inds,
  filter_summary=permlib.filtsum,
  filter_detail=permlib.filtdet,
  lock_table=permlib.locktable,
  maxkeytable=permlib.maxkey,
  outresult=work.result,
  outquery=work.query,
  mdebug=1
)
/* ensure only one record created */
%mp_assertdsobs(permlib.filtsum,
  desc=Initial query - same obs,
  test=ATMOST 1,
  outds=work.test_results
)
/* check RK is correct */
proc sql noprint;
select max(filter_rk) into: test2 from work.result;
%mp_assert(iftrue=(&test2=1),
  desc=Ensure filter rk is correct for second run,
  outds=work.test_results
)
