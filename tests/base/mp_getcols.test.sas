/**
  @file
  @brief Testing mp_getcols macro

  <h4> SAS Macros </h4>
  @li mp_getcols.sas
  @li mp_assert.sas
  @li mp_assertcols.sas
  @li mp_assertcolvals.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas

**/


/* make some data.  SOME_DATE2 / SOME_TIME2 carry formats the old prefix test
  did not know about */
proc sql;
create table work.src(
  SOME_DATETIME float format=datetime19.,
  SOME_CHAR char(16),
  SOME_NUM num,
  SOME_TIME num format=time8.,
  SOME_DATE num format=date9.,
  SOME_DATE2 num format=ddmmyyb10.,
  SOME_TIME2 num format=hhmm8.
);

/* run macro, checking for scope leakage */
%mp_assertscope(SNAPSHOT)
%mp_getcols(work.src,outds=work.info)
%mp_assertscope(COMPARE)

%mp_assertdsobs(work.info,
  desc=Has 7 records,
  test=EQUALS 7,
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

/* DDMMYYB and HHMM are in the format lists but are not DATE / TIME prefixed,
  so a prefix test would leave them as NUMERIC */
%let dttmcols=0;
proc sql noprint;
select count(*) into: dttmcols from work.info
  where (name='SOME_DATE2' and ddtype='DATE')
      or (name='SOME_TIME2' and ddtype='TIME');
quit;
%mp_assert(
  iftrue=(&dttmcols=2),
  desc=Formats a prefix test would miss are still classified,
  outds=work.test_results
)
