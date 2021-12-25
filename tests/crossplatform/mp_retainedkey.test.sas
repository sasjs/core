/**
  @file
  @brief Testing mp_retainedkey macro

  <h4> SAS Macros </h4>
  @li mp_assert.sas
  @li mp_assertcolvals.sas
  @li mp_retainedkey.sas

**/

/**
  * Setup base tables
  */
proc sql;
create table work.maxkeytable(
    keytable varchar(41) label='Base table in libref.dataset format',
    keycolumn char(32) format=$32.
      label='The Retained key field containing the key values.',
    max_key num label=
      'Integer representing current max RK or SK value in the KEYTABLE',
    processed_dttm num format=E8601DT26.6
      label='Datetime this value was last updated',
  constraint pk_mpe_maxkeyvalues
      primary key(keytable));

create table work.locktable(
    lock_lib char(8),
    lock_ds char(32),
    lock_status_cd char(10) not null,
    lock_user_nm char(100) not null ,
    lock_ref char(200),
    lock_pid char(10),
    lock_start_dttm num format=E8601DT26.6,
    lock_end_dttm num format=E8601DT26.6,
  constraint pk_mp_lockanytable primary key(lock_lib,lock_ds));

data work.targetds;
  rk_col=_n_;
  set sashelp.class;
run;

data work.appendtable;
  set sashelp.class;
  if mod(_n_,2)=0 then name=cats('New',_n_);
  if _n_<7;
run;

libname x (work);

/** Test 1 - base case **/
%mp_retainedkey(
  base_lib=X
  ,base_dsn=targetds
  ,append_lib=X
  ,append_dsn=APPENDTABLE
  ,retained_key=rk_col
  ,business_key= name
  ,check_uniqueness=NO
  ,maxkeytable=0
  ,locktable=0
  ,outds=work.APPEND
  ,filter_str=
)
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking errors in test 1,
  outds=work.test_results
)

data work.check;
  do val=1,3,5,20,21,22;
    output;
  end;
run;
%mp_assertcolvals(work.append.rk_col,
  checkvals=work.check.val,
  desc=All values have a match,
  test=ALLVALS
)

/** Test 2 - all new records, with metadata logging and unique check **/
data work.targetds2;
  rk_col=_n_;
  set sashelp.class;
run;

data work.appendtable2;
  set sashelp.class;
  do x=1 to 21;
    name=cats('New',x);
    output;
  end;
  stop;
run;

%mp_retainedkey(base_dsn=targetds2
  ,append_dsn=APPENDTABLE2
  ,retained_key=rk_col
  ,business_key= name
  ,check_uniqueness=YES
  ,maxkeytable=x.maxkeytable
  ,locktable=work.locktable
  ,outds=WORK.APPEND2
  ,filter_str=
)
%mp_assert(
  iftrue=(&syscc=0),
  desc=Checking errors in test 2,
  outds=work.test_results
)
%mp_assert(
  iftrue=(%mf_nobs(work.append2)=21),
  desc=Checking append records created,
  outds=work.test_results
)
