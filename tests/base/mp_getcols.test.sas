/**
  @file
  @brief Testing mp_getcols macro

  <h4> SAS Macros </h4>
  @li mp_getcols.sas
  @li mp_assertcols.sas
  @li mp_assertcolvals.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas

**/


/* make some data */
proc sql;
create table work.src(
  SOME_DATETIME float format=datetime19.,
  SOME_CHAR char(16),
  SOME_NUM num,
  SOME_TIME num format=time8.,
  SOME_DATE num format=date9.
);

/* run macro, checking for scope leakage */
%mp_assertscope(SNAPSHOT)
%mp_getcols(work.src,outds=work.info)
%mp_assertscope(COMPARE)

%mp_assertdsobs(work.info,
  desc=Has 5 records,
  test=EQUALS 5,
  outds=work.test_results
)

data work.check;
  length val $10;
  do val='NUMERIC','DATE','CHARACTER','DATETIME','TIME';
    output;
  end;
run;
%mp_assertcolvals(work.info.ddtype,
  checkvals=work.check.val,
  desc=All values have a match,
  test=ALLVALS
)

%mp_assertcols(work.info,
  cols=name type length varnum format label ddtype fmtname,
  test=ALL,
  desc=check all columns exist
)