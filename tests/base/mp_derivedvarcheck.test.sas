/**
  @file
  @brief Testing mp_derivedvarcheck macro

  <h4> SAS Macros </h4>
  @li mddl_derivedvars.sas
  @li mp_assertcols.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas
  @li mp_derivedvarcheck.sas

**/

/* one row per rule, plus the rows that must survive the scan */
%mddl_derivedvars(libds=work.cases)

data work.payload;
  length var_logic $4000;
  /* a complete SAS program with no literal semicolon anywhere in the source -
    every character rule passes and only the function name gives it away */
  var_logic="dosubl(cats('data _null_',byte(59),'data work.pwn',byte(59)
    ,'run',byte(59)))";
run;

proc sql;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='ok_band',var_deps='AGE'
    ,var_type='C',var_len=8,var_fmt='',var_logic="ifc(AGE>13,'TEEN','JUNIOR')"
    ,active=1;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='ok_literal',var_deps='AGE'
    ,var_type='C',var_len=8,var_fmt=''
    ,var_logic="ifc(AGE>13,'DOSUBL(','NO')",active=1;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='ok_label',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='best12.',var_logic='AGE*2'
    ,var_label='Age - doubled',active=1;
/* a line break in the label is flattened to a space rather than refused, so a
  control table that carries a wrapped label keeps working */
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='ok_multiline',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',var_logic='AGE*3'
    ,var_label='line one'||byte(10)||'line two',active=1;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='bad name',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',var_logic='AGE',active=1;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='1st',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',var_logic='AGE',active=1;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='_n_',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',var_logic='AGE',active=1;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='reserved_nm',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',var_logic='AGE',active=1;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='collides',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',var_logic='AGE',active=1;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='bad_type',var_deps='AGE'
    ,var_type='X',var_len=8,var_fmt='',var_logic='AGE',active=1;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='bad_len',var_deps='AGE'
    ,var_type='N',var_len=9,var_fmt='',var_logic='AGE',active=1;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='bad_fmt',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='best12.;x',var_logic='AGE',active=1;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='bad_label',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',var_logic='AGE'
    ,var_label='bell'||byte(1)||'here',active=1;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='semicolon',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',var_logic='AGE;',active=1;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='comment',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',var_logic='AGE /* x */',active=1;
insert into work.cases
  (libref,dsn,var_nm,var_deps,var_type,var_len,var_fmt,var_logic,active)
  select 'WORK','CLASS','pwn','','N',8,'',var_logic,1 from work.payload;
/* the file system is refused in both directions - assigning a fileref,
  copying a file and deleting one are all names in the expression */
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='fs_name',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt=''
    ,var_logic="filename('c1','/tmp/x.txt')",active=1;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='fs_del',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',var_logic="fdelete('c1')",active=1;
insert into work.cases
  set libref='WORK',dsn='CLASS',var_nm='fs_copy',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt=''
    ,var_logic="fcopy('c1','c2')",active=1;
quit;

%mp_assertscope(SNAPSHOT)
%mp_derivedvarcheck(
  inds=work.cases,
  outds=work.fails,
  physlist=%str(AGE SEX COLLIDES),
  reserved=%str(RESERVED_NM),
  denyfuncs=%str(mydeniedfunc)
)

/* 19 rows: 4 valid, 15 that break a rule */
%mp_assertdsobs(work.fails,
  desc=One row is reported per invalid definition,
  test=EQUALS 15,
  outds=work.test_results
)

%mp_assertcols(work.fails,
  desc=The output carries NAME and REASON,
  cols=NAME REASON,
  test=ALL,
  outds=work.test_results
)

data work.chk;
  set work.fails;
  where name in ('OK_BAND','OK_LITERAL','OK_LABEL','OK_MULTILINE');
run;

%mp_assertdsobs(work.chk,
  desc=No valid definition is reported,
  test=EQUALS 0,
  outds=work.test_results
)

data work.chk2;
  set work.fails;
  where missing(reason);
run;

%mp_assertdsobs(work.chk2,
  desc=Every reported row carries a reason,
  test=EQUALS 0,
  outds=work.test_results
)

/* the two rules that need a list from the caller are skipped when it is not
  supplied - the other thirteen still fire */
%mp_derivedvarcheck(
  inds=work.cases,
  outds=work.fails2
)

%mp_assertdsobs(work.fails2,
  desc=The optional lists change only their own rules,
  test=EQUALS 13,
  outds=work.test_results
)

/* denyfuncs adds to the built-in list rather than replacing it: the same row
  is clean without it, refused with it, and a built-in name is still refused */
%mddl_derivedvars(libds=work.cases2)

proc sql;
insert into work.cases2
  set libref='WORK',dsn='CLASS',var_nm='sitefunc',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',var_logic='MYDENIEDFUNC(AGE)',active=1;
insert into work.cases2
  set libref='WORK',dsn='CLASS',var_nm='builtin',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',var_logic='sleep(AGE)',active=1;
quit;

%mp_derivedvarcheck(
  inds=work.cases2,
  outds=work.fails4,
  denyfuncs=%str(MYDENIEDFUNC)
)

%mp_assertdsobs(work.fails4,
  desc=denyfuncs adds a name without dropping the built-in list,
  test=EQUALS 2,
  outds=work.test_results
)

%mp_derivedvarcheck(
  inds=work.cases2,
  outds=work.fails5
)

%mp_assertdsobs(work.fails5,
  desc=Without denyfuncs only the built-in name is refused,
  test=EQUALS 1,
  outds=work.test_results
)

%mp_assertscope(COMPARE,ignorelist=_SASJS_WEBOUT_HEADERS,
  outds=work.test_results
)
