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

  @sasjslint {"maxLineLength": 81}
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

/* a filter containing quotes must not break the macro - a datetime literal
  is the usual case, and quoting it again inside an %if condition does */
%mp_derivedvars(
  libds=work.class,
  control=work.derived_vars,
  where=%str(var_nm ne "NOPE"),
  outref=derref11,
  outvars=work.dvnames11,
  outview=work.vw_wherequote
)

%mp_assertdsobs(work.dvnames11,
  desc=A filter containing quotes is applied,
  test=EQUALS 1,
  outds=work.test_results
)

%mp_assert(
  iftrue=(0 < %mf_existvar(work.vw_wherequote,BAND)),
  desc=The view is still built when the filter contains quotes,
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

/* a diamond graph - two variables built on one, then a fourth on both, then a
  fifth on that.  Rows are loaded in reverse name order so nothing but the
  dependency sort can produce the right sequence */
%mddl_derivedvars(libds=work.dvcfg_diamond)

proc sql;
insert into work.dvcfg_diamond
  set libref='WORK',dsn='CLASS',var_nm='v5',var_deps='SEX V4'
    ,var_type='C',var_len=40,var_fmt='',var_logic="cats(SEX,'-',put(V4,best12.))"
    ,active=1;
insert into work.dvcfg_diamond
  set libref='WORK',dsn='CLASS',var_nm='v4',var_deps='V2 V3'
    ,var_type='N',var_len=8,var_fmt='',var_logic='V2 + V3',active=1;
insert into work.dvcfg_diamond
  set libref='WORK',dsn='CLASS',var_nm='v3',var_deps='V1'
    ,var_type='N',var_len=8,var_fmt='',var_logic='V1 + 1',active=1;
insert into work.dvcfg_diamond
  set libref='WORK',dsn='CLASS',var_nm='v2',var_deps='V1'
    ,var_type='N',var_len=8,var_fmt='',var_logic='V1 * 2',active=1;
insert into work.dvcfg_diamond
  set libref='WORK',dsn='CLASS',var_nm='v1',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',var_logic='AGE + 0',active=1;
quit;

%mp_derivedvars(
  libds=work.class,
  control=work.dvcfg_diamond,
  outref=derref8,
  outview=work.vw_diamond
)

%mp_assertcols(work.vw_diamond,
  desc=The diamond graph is fully materialised,
  cols=V1 V2 V3 V4 V5,
  test=ALL,
  outds=work.test_results
)

data work.chkdiamond;
  set work.vw_diamond;
  if v1 ne age then output;
  if v2 ne age*2 then output;
  if v3 ne age+1 then output;
  if v4 ne age*3+1 then output;
  if v5 ne cats(sex,'-',put(age*3+1,best12.)) then output;
run;

%mp_assertdsobs(work.chkdiamond,
  desc=Every variable in the diamond graph resolves to the right value,
  test=EQUALS 0,
  outds=work.test_results
)

/* the assignment order must be v1, then v2 and v3, then v4, then v5 */
data work.chkorder;
  infile derref8 truncover;
  input line $4000.;
  seq=_n_;
  length nm $32;
  if prxmatch('/^V\d+\s*=/',strip(line)) then nm=scan(strip(line),1,'=');
  else nm='';
run;

data work.chkorder2;
  set work.chkorder end=eof;
  retain s1 s2 s3 s4 s5;
  if nm='V1' then s1=seq;
  if nm='V2' then s2=seq;
  if nm='V3' then s3=seq;
  if nm='V4' then s4=seq;
  if nm='V5' then s5=seq;
  if eof;
  if missing(s1) or missing(s2) or missing(s3) or missing(s4) or missing(s5)
    then output;
  else if s1 ge min(s2,s3) then output;
  else if max(s2,s3) ge s4 then output;
  else if s4 ge s5 then output;
run;

%mp_assertdsobs(work.chkorder2,
  desc=The diamond graph is assigned in dependency order,
  test=EQUALS 0,
  outds=work.test_results
)

/* a label longer than the 256 limit, containing quotes, must still produce a
  literal SAS can parse - the truncation cannot split a doubled quote */
%mddl_derivedvars(libds=work.dvcfg_long)

data work.longcfg;
  length logic $4000;
  logic=cats("ifc(AGE>13,'",repeat('a',300),"','short')");
run;

proc sql;
insert into work.dvcfg_long
  (libref,dsn,var_nm,var_deps,var_type,var_len,var_fmt,var_logic,active)
  select 'WORK','CLASS','LONG_LABEL','AGE','C',400,'',logic,1
  from work.longcfg;
quit;

%mp_derivedvars(
  libds=work.class,
  control=work.dvcfg_long,
  outref=derref9,
  outview=work.vw_long
)

data work.chkquotes;
  infile derref9 truncover;
  input line $4000.;
  if index(line,"label='")>0 and mod(count(line,"'"),2) ne 0 then output;
run;

%mp_assertdsobs(work.chkquotes,
  desc=A truncated label keeps an even quote count,
  test=EQUALS 0,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existds(libds=work.vw_long)=1),
  desc=A label longer than the limit still builds the view,
  outds=work.test_results
)

/* one control table can serve several tables - the LIBREF/DSN pair scopes the
  definitions, so the same name means different things on each */
data work.class2;
  set sashelp.class;
run;

%mddl_derivedvars(libds=work.dvcfg_multi)

proc sql;
insert into work.dvcfg_multi
  set libref='WORK',dsn='CLASS',var_nm='scaled',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='',var_logic='AGE + 100',active=1;
insert into work.dvcfg_multi
  set libref='WORK',dsn='CLASS2',var_nm='scaled',var_deps='AGE'
    ,var_type='N',var_len=8,var_fmt='dollar12.2',var_logic='AGE + 200',active=1;
quit;

%mp_derivedvars(
  libds=work.class,
  control=work.dvcfg_multi,
  outref=derref10,
  outview=work.vw_multi1
)

%mp_derivedvars(
  libds=work.class2,
  control=work.dvcfg_multi,
  outref=derref10,
  outview=work.vw_multi2
)

data work.chkmulti;
  merge work.vw_multi1(keep=name age scaled rename=(scaled=scaled1))
    work.vw_multi2(keep=name age scaled rename=(scaled=scaled2));
  by name;
  if scaled1 ne age + 100 then output;
  if scaled2 ne age + 200 then output;
run;

%mp_assertdsobs(work.chkmulti,
  desc=The same variable name means different things per table,
  test=EQUALS 0,
  outds=work.test_results
)

/* a configured format is applied as given - asserted on the statement the
  macro emits, which is what the view is built from */
data work.chkfmt;
  infile derref10 truncover;
  input line $4000.;
  if index(line,'format=DOLLAR12.2')>0 then output;
run;

%mp_assertdsobs(work.chkfmt,
  desc=A configured format is applied,
  test=EQUALS 1,
  outds=work.test_results
)

/* VAR_LOGIC is inserted into a generated assignment, so anything that submits
  code or reaches the file system or the macro symbol table has to be refused.
  The character rules cannot see these payloads: BYTE(59) builds the semicolon
  the source text must not contain.  Each payload below therefore passes every
  character check and must still be refused by name. */

/* A DOSUBL program built out of BYTE(59) - no literal semicolon, ampersand,
  percent or comment in the stored value */
data work.payload;
  length logic $4000;
  logic="dosubl(cats('data _null_',byte(59),'data work.pwn',byte(59)
    ,'run',byte(59)))";
run;

%mddl_derivedvars(libds=work.dvcfg_inject)

proc sql;
insert into work.dvcfg_inject
  (libref,dsn,var_nm,var_deps,var_type,var_len,var_fmt,var_logic,active)
  select 'WORK','CLASS','pwn','','N',8,'',logic,1 from work.payload;
quit;

%mp_derivedvars(
  libds=work.class,
  control=work.dvcfg_inject,
  outref=drefi,
  outview=work.vw_inj,
  outvars=work.dvn_inj,
  abort=NO,
  errds=work.dv_inj_err
)

%mp_assertdsobs(work.dv_inj_err,
  desc=A DOSUBL payload is refused even though it carries no semicolon,
  test=HASOBS,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existds(libds=work.vw_inj)=0),
  desc=No view is built for a refused payload,
  outds=work.test_results
)

/* the same for the file system and the macro symbol table */
data work.payload2;
  length logic $4000;
  logic="fread(fopen('/etc/hostname'))";
run;

%mddl_derivedvars(libds=work.dvcfg_fread)

proc sql;
insert into work.dvcfg_fread
  (libref,dsn,var_nm,var_deps,var_type,var_len,var_fmt,var_logic,active)
  select 'WORK','CLASS','leak','','C',200,'',logic,1 from work.payload2;
quit;

%mp_derivedvars(
  libds=work.class,
  control=work.dvcfg_fread,
  outref=dreff,
  outview=work.vw_fr,
  outvars=work.dvn_fr,
  abort=NO,
  errds=work.dv_fr_err
)

%mp_assertdsobs(work.dv_fr_err,
  desc=A file read payload is refused,
  test=HASOBS,
  outds=work.test_results
)

data work.payload3;
  length logic $4000;
  logic="symputx('syscc',0)";
run;

%mddl_derivedvars(libds=work.dvcfg_symput)

proc sql;
insert into work.dvcfg_symput
  (libref,dsn,var_nm,var_deps,var_type,var_len,var_fmt,var_logic,active)
  select 'WORK','CLASS','sneaky','','N',8,'',logic,1 from work.payload3;
quit;

%mp_derivedvars(
  libds=work.class,
  control=work.dvcfg_symput,
  outref=drefs,
  outview=work.vw_sp,
  outvars=work.dvn_sp,
  abort=NO,
  errds=work.dv_sp_err
)

%mp_assertdsobs(work.dv_sp_err,
  desc=A macro symbol table write is refused,
  test=HASOBS,
  outds=work.test_results
)

/* a per row delay turns one read of the table into a denial of service */
data work.payload4;
  length logic $4000;
  logic="sleep(10)";
run;

%mddl_derivedvars(libds=work.dvcfg_sleep)

proc sql;
insert into work.dvcfg_sleep
  (libref,dsn,var_nm,var_deps,var_type,var_len,var_fmt,var_logic,active)
select 'WORK','CLASS','slow','','N',8,'',logic,1 from work.payload4;
quit;

%mp_derivedvars(
  libds=work.class,
  control=work.dvcfg_sleep,
  outref=drefz,
  outview=work.vw_sl,
  outvars=work.dvn_sl,
  abort=NO,
  errds=work.dv_sl_err
)

%mp_assertdsobs(work.dv_sl_err,
  desc=A per row delay is refused,
  test=HASOBS,
  outds=work.test_results
)

/* the control: a refused word inside a quoted literal is data, not a call */
data work.payload5;
  length logic $4000;
  logic="ifc(SEX='DOSUBL(','Y','N')";
run;

%mddl_derivedvars(libds=work.dvcfg_literal)

proc sql;
insert into work.dvcfg_literal
  (libref,dsn,var_nm,var_deps,var_type,var_len,var_fmt,var_logic,active)
  select 'WORK','CLASS','literal_ok','SEX','C',1,'',logic,1 from work.payload5;
quit;

%mp_derivedvars(
  libds=work.class,
  control=work.dvcfg_literal,
  outref=drefc,
  outview=work.vw_lit,
  outvars=work.dvn_lit,
  abort=NO,
  errds=work.dv_lit_err
)

%mp_assertdsobs(work.dv_lit_err,
  desc=A refused word inside a quoted literal is allowed,
  test=EQUALS 0,
  outds=work.test_results
)

%mp_assert(
  iftrue=(0 < %mf_existvar(work.vw_lit,LITERAL_OK)),
  desc=The literal control still builds its view,
  outds=work.test_results
)

/* abort=NO reports every rule a definition breaks, not just the first: one
  row references an undeclared derived variable, the other carries a bad
  field, and both are returned in the same pass */
%mddl_derivedvars(libds=work.dvcfg_multi)

proc sql;
insert into work.dvcfg_multi
  set libref='WORK',dsn='CLASS',var_nm='aaa',var_deps=''
    ,var_type='N',var_len=8,var_fmt='',var_logic='zzz+1',active=1;
insert into work.dvcfg_multi
  set libref='WORK',dsn='CLASS',var_nm='zzz',var_deps='AGE'
    ,var_type='X',var_len=8,var_fmt='',var_logic='AGE',active=1;
quit;

%mp_derivedvars(
  libds=work.class,
  control=work.dvcfg_multi,
  outref=drefm,
  outview=work.vw_multi,
  outvars=work.dvn_multi,
  abort=NO,
  errds=work.dv_multi_err
)

%mp_assertdsobs(work.dv_multi_err,
  desc=abort NO reports every broken rule not just the first,
  test=EQUALS 2,
  outds=work.test_results
)

%mp_assert(
  iftrue=(%mf_existds(libds=work.vw_multi)=0),
  desc=abort NO builds no view when any rule fails,
  outds=work.test_results
)

%mp_assertscope(COMPARE,ignorelist=_SASJS_WEBOUT_HEADERS,outds=work.test_results)
