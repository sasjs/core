/**
  @file
  @brief Testing mp_derivedvars macro

  <h4> SAS Macros </h4>
  @li mddl_derivedvars.sas
  @li mf_existds.sas
  @li mf_existvar.sas
  @li mf_nobs.sas
  @li mp_assert.sas
  @li mp_assertcols.sas
  @li mp_assertdsobs.sas
  @li mp_assertscope.sas
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
  set libref='WORK',dsn='CLASS',var_nm='band',var_deps='AGE'
    ,var_type='C',var_len=8,var_fmt='',active=1
    ,var_logic="ifc(AGE>13,'TEEN','JUNIOR')";
insert into work.dvcfg
  set libref='WORK',dsn='CLASS',var_nm='band_age',var_deps='BAND AGE'
    ,var_type='C',var_len=16,var_fmt='',active=1
    ,var_logic="cats(BAND,'-',AGE)";
insert into work.dvcfg
  set libref='WORK',dsn='CLASS',var_nm='double_age',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',active=1
    ,var_logic='AGE * 2';
/* loaded first, so the dependency order cannot come from the row order */
insert into work.dvcfg
  set libref='WORK',dsn='CLASS',var_nm='band_label',var_deps='BAND SEX'
    ,var_type='C',var_len=32,var_fmt='',active=1
    ,var_logic="cats(BAND,'-',SEX)";
/* inactive - should be excluded by the where clause */
insert into work.dvcfg
  set libref='WORK',dsn='CLASS',var_nm='ignored',var_deps=''
    ,var_type='C',var_len=8,var_fmt='',active=0
    ,var_logic="'X'";
quit;

/* the setup SQL above creates the SQL automatic macro variables, so the
  snapshot is taken here - the check is for the macro's own leakage */
%mp_assertscope(SNAPSHOT)

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
  test=EQUALS 4,
  outds=work.test_results
)

%mp_assertcols(work.vw_dv,
  desc=The view carries the derived columns,
  cols=BAND BAND_AGE DOUBLE_AGE BAND_LABEL,
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
  if band_label ne cats(band,'-',SEX) then output;
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

/* the statements are generated in dependency order, not in the order the
  rows were loaded - BAND must be assigned before BAND_AGE */
data work.stmts;
  infile derref truncover;
  input line $4000.;
  seq=_n_;
run;

data work.chkord;
  set work.stmts end=eof;
  retain band_seq bandage_seq;
  if prxmatch('/^BAND\s*=/',strip(line)) and missing(band_seq) then band_seq=seq;
  if prxmatch('/^BAND_AGE\s*=/',strip(line)) and missing(bandage_seq)
    then bandage_seq=seq;
  if eof;
  if missing(band_seq) or missing(bandage_seq) or band_seq>=bandage_seq
    then output;
run;

%mp_assertdsobs(work.chkord,
  desc=BAND is assigned before BAND_AGE whatever order the rows were loaded,
  test=EQUALS 0,
  outds=work.test_results
)

/* VAR_LABEL overrides the default label, and falls back when it is blank */
%mddl_derivedvars(libds=work.dvcfg_label)

proc sql;
insert into work.dvcfg_label
  set libref='WORK',dsn='CLASS',var_nm='band',var_deps='AGE'
    ,var_type='C',var_len=8,var_fmt='',var_label='Age band'
    ,var_logic="ifc(AGE>13,'TEEN','JUNIOR')",active=1;
insert into work.dvcfg_label
  set libref='WORK',dsn='CLASS',var_nm='double_age',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',var_label=''
    ,var_logic='AGE * 2',active=1;
quit;

%mp_derivedvars(
  libds=work.class,
  control=work.dvcfg_label,
  outref=derref7,
  outview=work.vw_label
)

/* assert on the generated statements - the label in the view can be changed
  again by proc contents, the statement is what the macro emits */
data work.stmts7;
  infile derref7 truncover;
  input line $4000.;
run;

data work.chklbl;
  set work.stmts7 end=eof;
  retain found_custom found_default;
  if index(line,"label='Age band'")>0 then found_custom=1;
  if index(line,"label='DOUBLE_AGE=AGE * 2'")>0 then found_default=1;
  if eof;
  if not found_custom or not found_default then output;
run;

%mp_assertdsobs(work.chklbl,
  desc=VAR_LABEL is used when set and defaults when blank,
  test=EQUALS 0,
  outds=work.test_results
)

/* the default outvars name must not overwrite a control table that uses the
  mddl_derivedvars default - this is the pair of defaults a caller is likely
  to use */
%mddl_derivedvars(libds=work.derived_vars)

proc sql;
insert into work.derived_vars
  set libref='WORK',dsn='CLASS',var_nm='band',var_deps='AGE'
    ,var_type='C',var_len=8,var_fmt='',active=1
    ,var_logic="ifc(AGE>13,'TEEN','JUNIOR')";
quit;

%mp_derivedvars(
  libds=work.class,
  control=work.derived_vars,
  outref=derref5,
  outview=work.vw_default
)

%mp_assert(
  iftrue=(0 < %mf_existvar(work.vw_default,BAND)),
  desc=The default outvars does not overwrite the control table,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_nobs(work.derived_vars)=1),
  desc=The control table survives the default outvars name,
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

%mp_assertscope(COMPARE,ignorelist=_SASJS_WEBOUT_HEADERS,outds=work.test_results)
