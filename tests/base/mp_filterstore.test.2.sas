/**
  @file
  @brief Testing mp_filterstore macro with a format catalog

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas
  @li mp_coretable.sas
  @li mp_filterstore.sas

**/

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
AND,AND,1,Start,>,"'2'"
AND,AND,1,Fmtname,=,"'MORDOR'"
OR,OR,2,Label,IN,"('Dragon1','Dragon2')"
OR,OR,2,End,=,"'6'"
OR,OR,2,Start,GE,"'10'"
;;;;
run;

/* make some formats */
PROC FORMAT library=permlib.testfmts;
  picture MyMSdt other='%0Y-%0m-%0dT%0H:%0M:%0S' (datatype=datetime);
RUN;
data work.fmts;
  length fmtname $32;
  do fmtname='SMAUG','MORDOR','GOLLUM';
    do start=1 to 10;
      label= cats('Dragon ',start);
      output;
    end;
  end;
run;
proc sort data=work.fmts nodupkey;
  by fmtname start;
run;
proc format cntlin=work.fmts library=permlib.testfmts;
run;
proc format library=permlib.testfmts;
  invalue indays (default=13) other=42;
run;


%mp_assertscope(SNAPSHOT)
%mp_filterstore(libds=permlib.testfmts-fc,
  queryds=work.inds,
  filter_summary=permlib.filtsum,
  filter_detail=permlib.filtdet,
  lock_table=permlib.locktable,
  maxkeytable=permlib.maxkey,
  outresult=work.result,
  outquery=work.query,
  mdebug=1
)
%mp_assertscope(COMPARE)

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
%mp_filterstore(libds=permlib.testfmts-fc,
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
