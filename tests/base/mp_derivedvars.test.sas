/**
  @file
  @brief Testing mp_derivedvars macro

  <h4> SAS Macros </h4>
  @li mddl_derivedvars.sas
  @li mf_existds.sas
  @li mf_existvar.sas
  @li mp_assert.sas
  @li mp_assertcols.sas
  @li mp_assertdsobs.sas
  @li mp_derivedvars.sas

**/

/* the target table */
data work.class;
  set sashelp.class;
run;

/* the control table */
%mddl_derivedvars(libds=work.dvcfg)

proc sql;
insert into work.dvcfg
  set libref='WORK',dsn='CLASS',var_nm='band',var_order=10
    ,var_type='C',var_len=8,var_fmt='',active=1
    ,var_logic="ifc(AGE>13,'TEEN','JUNIOR')";
insert into work.dvcfg
  set libref='WORK',dsn='CLASS',var_nm='band_age',var_order=20
    ,var_type='C',var_len=16,var_fmt='',active=1
    ,var_logic="cats(BAND,'-',AGE)";
insert into work.dvcfg
  set libref='WORK',dsn='CLASS',var_nm='double_age',var_order=30
    ,var_type='N',var_len=8,var_fmt='',active=1
    ,var_logic='AGE * 2';
/* inactive - should be excluded by the where clause */
insert into work.dvcfg
  set libref='WORK',dsn='CLASS',var_nm='ignored',var_order=40
    ,var_type='C',var_len=8,var_fmt='',active=0
    ,var_logic="'X'";
quit;

%mp_derivedvars(
  libds=work.class,
  control=work.dvcfg,
  where=%str(active=1),
  outref=derref,
  outview=work.vw_dv,
  outvars=work.dvnames,
  reserved=%str(_____DELETE__THIS__RECORD_____ TX_FROM TX_TO)
)

/* one row per variable, names upcased, inactive row excluded */
%mp_assertdsobs(work.dvnames,
  desc=Only the active variables are returned,
  test=EQUALS 3,
  outds=work.test_results
)

%mp_assertcols(work.vw_dv,
  desc=The view carries the derived columns,
  cols=BAND BAND_AGE DOUBLE_AGE,
  test=ALL,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existvar(work.vw_dv,IGNORED)=0),
  desc=The inactive variable is not in the view,
  outds=work.test_results
)

/* the values, including a variable built on another one */
data work.chk;
  set work.vw_dv;
  where band='TEEN';
  if band_age ne cats(band,'-',AGE) then output;
  if double_age ne AGE*2 then output;
run;

%mp_assertdsobs(work.chk,
  desc=Derived values and chained values are correct,
  test=EQUALS 0,
  outds=work.test_results
)

data work.chk2;
  set work.vw_dv;
  where band='TEEN';
run;

%mp_assertdsobs(work.chk2,
  desc=A derived variable can be filtered on,
  test=HASOBS,
  outds=work.test_results
)

/* the label is the variable name plus the expression */
proc contents noprint data=work.vw_dv out=work.vcols(keep=name label);
run;

data work.chklab;
  set work.vcols;
  where name='BAND' and label=:'BAND=ifc(AGE>13';
run;

%mp_assertdsobs(work.chklab,
  desc=The label carries the variable name and the expression,
  test=EQUALS 1,
  outds=work.test_results
)

%mp_assert(
  iftrue=("%mf_existds(libds=work.vw_dv)"="1"),
  desc=The view was built,
  outds=work.test_results
)

/* a control table with no rows for the target leaves everything empty */
%mddl_derivedvars(libds=work.dvcfg_empty)

%mp_derivedvars(
  libds=work.class,
  control=work.dvcfg_empty,
  outref=derref3,
  outview=work.vw_empty,
  outvars=work.dvnames3
)

%mp_assertdsobs(work.dvnames3,
  desc=No rows in the control table means no variables,
  test=EQUALS 0,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existds(libds=work.vw_empty)=0),
  desc=No view is built when there is nothing to derive,
  outds=work.test_results
)

/* a missing control table is not an error, it just means no variables */
%mp_derivedvars(
  libds=work.class,
  control=work.doesnotexist,
  outref=derref4,
  outvars=work.dvnames4
)

%mp_assertdsobs(work.dvnames4,
  desc=A missing control table yields no variables,
  test=EQUALS 0,
  outds=work.test_results
)
