/**
  @file
  @brief Generates the SAS statements that create derived variables
  @details Derived (computed) variables are configured in a control table, one
  row per variable.  The macro writes the statements that create them to a
  fileref, so that callers can compose them into a view:

      %mp_derivedvars(libds=&libds,control=perm.derived_vars,outref=dercode)
      data work.vw_derived / view=work.vw_derived;
        set &libds;
        %include dercode;
      run;

  Alternatively pass outview= and the macro will build the view itself.

  Building a view is what makes a derived variable filterable.  A WHERE
  statement applies to the data set named on the SET statement, so it cannot
  reference a variable created in the same data step:

      data out;
        set work.vw_derived;
        where <filter>;
      run;

  Each variable produces two statements:

      attrib REGION length=$21 label='REGION=<expression>' format=$21.;
      REGION = <expression>;

  Type and length are declared in the control table, so the result is
  deterministic.

  VAR_DEPS lists every input the expression uses - physical columns
  and derived variables alike.  The order the statements are generated in is
  the dependency order (variables with no unsatisfied dependency first, ties
  broken by name), so a derived variable may build on another one without the
  administrator maintaining a sequence number.  A cycle is rejected.

  The declaration is checked against the expression: a derived variable that
  is referenced must be declared, a declared name that is not referenced is an
  error, and a declared name must be a column of the target table or a derived
  variable defined for it.  Semicolons, macro triggers and comments are
  rejected, so a row can only ever be an expression.

  The field level rules are not here - they are in mp_derivedvarcheck, which
  reads the same control table and writes one row per definition that breaks
  one.  This macro adds the two checks that need the target table, and the
  dependency graph, then generates the statements.

  A derived variable may
  not reuse the name of a physical column, and may not reference itself: an
  intra-row calculation would imply a retained value, which depends on the
  order rows happen to arrive in.

  VAR_LABEL is optional.  When it is missing or blank, the label is the
  variable name, an equals sign and the expression - so a reader can see both
  what the column is and where it comes from.  A configured label replaces
  that, and is used as given.

  The control table is created by mddl_derivedvars.sas, and must carry LIBREF,
  DSN, VAR_NM, VAR_DEPS, VAR_TYPE, VAR_LEN, VAR_FMT and VAR_LOGIC, with
  VAR_LABEL optional.  Extra columns are ignored, but a control table that
  holds several versions of the same VAR_NM - for example a bitemporal
  TX_FROM / TX_TO pair - must be narrowed with where= (typically to the
  current versions), because two rows with the same name are rejected as a
  configuration error.

  <h4> SAS Macros </h4>
  @li mf_existds.sas
  @li mf_existvar.sas
  @li mf_getuniquename.sas
  @li mf_getvarlist.sas
  @li mf_nobs.sas
  @li mp_abort.sas
  @li mp_derivedvarcheck.sas

  <h4> Related Macros </h4>
  @li mddl_derivedvars.sas

  @param [in] libds= The target table (libref.dataset, lib must be assigned)
  @param [in] control= The control table holding the variable definitions
  @param [in] where= (0) Optional additional filter for the control table
  @param [out] outref= (0) Fileref to receive the generated statements
  @param [out] outvars= (work.derived_varlist) Dataset of derived variable names
  @param [in] outview= (0) Optional two-level name for the derived view
  @param [in] reserved= (0) Space separated list of names that may not be used
  @param [in] abort= (YES) Set to NO to return the validation failures in
    errds= instead of aborting - for tests, and for a caller that wants to
    report every failure rather than the first
  @param [out] errds= (work.dv_errors) The validation failures when abort=NO:
    one row per offending VAR_NM with the rule it broke in REASON.  Empty, not
    absent, when the configuration is valid

  @version 5.6
  @author 4GL Apps Ltd

**/

%macro mp_derivedvars(libds=,
  control=,
  where=0,
  outref=0,
  outvars=work.derived_varlist,
  outview=0,
  reserved=0,
  abort=YES,
  errds=work.dv_errors
);

%local physlist phys_sp derived_err left nready nplaced
  cyc_start cyc_cur cyc_next cyc_path cyc_seen cyc_i
  ds_cfg ds_byname ds_bad ds_baddep ds_dup ds_dep ds_ref ds_stale
  ds_undecl ds_self ds_edge ds_todo ds_ready ds_placed ds_srt;

/* every working table gets its own name, so a caller with tables of the same
  name in WORK cannot collide with this macro's intermediates */
%let ds_cfg=%mf_getuniquename(prefix=dvcfg);
%let ds_byname=%mf_getuniquename(prefix=dvbyn);
%let ds_bad=%mf_getuniquename(prefix=dvbad);
%let ds_baddep=%mf_getuniquename(prefix=dvbdp);
%let ds_dup=%mf_getuniquename(prefix=dvdup);
%let ds_dep=%mf_getuniquename(prefix=dvdep);
%let ds_ref=%mf_getuniquename(prefix=dvref);
%let ds_stale=%mf_getuniquename(prefix=dvstl);
%let ds_undecl=%mf_getuniquename(prefix=dvund);
%let ds_self=%mf_getuniquename(prefix=dvsfl);
%let ds_edge=%mf_getuniquename(prefix=dvedg);
%let ds_todo=%mf_getuniquename(prefix=dvtd);
%let ds_ready=%mf_getuniquename(prefix=dvrdy);
%let ds_placed=%mf_getuniquename(prefix=dvpld);
%let ds_srt=%mf_getuniquename(prefix=dvsrt);

%mp_abort(iftrue= (%length(&libds)=0 or %length(&control)=0)
  ,mac=&sysmacroname
  ,msg=%str(Missing: libds control)
)
%mp_abort(iftrue= (&outref = 0)
  ,mac=&sysmacroname
  ,msg=%str(Please provide an outref for the generated statements)
)
%mp_abort(iftrue= (%mf_existds(libds=&libds) ne 1)
  ,mac=&sysmacroname
  ,msg=%str(Target table not found: &libds)
)

/* a long label can push a statement past the default record length, which
  would wrap it and break the generated code */
filename &outref temp lrecl=32767;

/* ensure the outputs exist, and are empty */
data _null_;
  file &outref;
run;
data &outvars(keep=name);
  length name $32;
  name='';
  if 0;
run;

/* the failures dataset exists even when the configuration is valid, so a
  caller can test it without checking for existence first */
data &errds(keep=name reason);
  length name $32 reason $200;
  name='';
  reason='';
  if 0;
run;

%if %mf_existds(libds=&control) ne 1 %then %do;
  %put &sysmacroname: &control not found - no derived variables;
  %return;
%end;

data work.&ds_cfg.;
  set &control;
  /* %superq, because a filter can legitimately contain quotes - a datetime
    literal such as "21OCT2026:09:00:00"dt is the usual case, and quoting it
    again inside a %if condition breaks the evaluation */
  %if %superq(where) ne 0 %then %do;
    where &where;
  %end;
  where also upcase(libref)="%upcase(%scan(&libds,1,.))"
    and upcase(dsn)="%upcase(%scan(&libds,2,.))";
  length name $32 logic $4000 fmt $32 deps $4000 lbl $256;
  name=upcase(strip(var_nm));
  logic=strip(var_logic);
  type=upcase(strip(var_type));
  len=var_len;
  fmt=strip(upcase(var_fmt));
  deps=upcase(strip(var_deps));
  /* VAR_LABEL is optional - older control tables may not have the column */
  /* mf_existvar returns the variable position, so 0 means absent */
  %if %mf_existvar(&control,VAR_LABEL) gt 0 %then %do;
    lbl=translate(strip(var_label),' ','0D0A'x);
  %end;
  %else %do;
    lbl='';
  %end;
run;

%if %mf_nobs(work.&ds_cfg.)=0 %then %return;

proc sort data=work.&ds_cfg. out=work.&ds_byname.;
  by name;
run;

/* the columns of the target, twice - as an in-list for the SQL below, and as
  the space separated form mp_derivedvarcheck takes */
%let physlist=%upcase(%mf_getvarlist(&libds,dlm=%str(,),quote=SINGLE));
%let phys_sp=%upcase(%mf_getvarlist(&libds));

/* the field level rules live in mp_derivedvarcheck, so the same scan can be
  run before a definition is ever used - at submit time, or over a table of
  expressions in a code scanning tool.  The engine supplies what only it can
  know: the columns of the target table, which is what the collision and the
  dependency checks are compared against. */
%mp_derivedvarcheck(inds=work.&ds_byname.
  ,outds=work.&ds_bad.
  ,physlist=&phys_sp
  ,reserved=&reserved
)

data work.&ds_dup.(keep=name reason);
  set work.&ds_byname.;
  by name;
  length reason $200;
  if first.name and not last.name;
  reason='VAR_NM is defined more than once';
run;

proc append base=work.&ds_bad. data=work.&ds_dup.;
run;

/**
  * The declared dependencies, one row per word
  */
data work.&ds_dep.;
  set work.&ds_byname.;
  length dep_nm $32;
  do i=1 to countw(deps,' ');
    dep_nm=scan(deps,i,' ');
    if not missing(dep_nm) then output;
  end;
  keep name dep_nm;
run;

/**
  * The identifiers the expression actually references - quoted strings are
  * removed first, so a name inside a literal is not mistaken for a reference
  */
data work.&ds_ref.;
  set work.&ds_byname.;
  length l $4000 tok $32;
  l=prxchange("s/'([^']|'')*'//",-1,logic);
  l=prxchange('s/"([^"]|"")*"//',-1,l);
  l=prxchange('s/[^A-Za-z0-9_]/ /',-1,upcase(l));
  do i=1 to countw(l,' ');
    tok=scan(l,i,' ');
    if not missing(tok) then output;
  end;
  keep name tok;
run;

/* a declared name must resolve - to a column of the target, or to a variable
  in this configuration */
proc sql noprint;
create table work.&ds_baddep. as
  select d.name, d.dep_nm
  from work.&ds_dep. d
  where d.dep_nm not in (select name from work.&ds_byname.)
  /* a table with no columns leaves physlist empty - fall back to the derived
    names alone rather than compiling an empty in-list */
  %if %length(&physlist)>0 %then %do;
    and d.dep_nm not in (%unquote(&physlist))
  %end;
  ;

/* every declared name must actually appear in the expression */
create table work.&ds_stale. as
  select d.name, d.dep_nm
  from work.&ds_dep. d
  where not exists (
    select 1 from work.&ds_ref. r
    where r.name=d.name and r.tok=d.dep_nm
  );

/* a derived variable referenced by the expression must be declared, otherwise
  the statement order would be wrong and the value would be silently missing */
create table work.&ds_undecl. as
  select distinct r.name, r.tok as dep_nm
  from work.&ds_ref. r
  where r.tok in (select name from work.&ds_byname.)
    and r.tok ne r.name
    and not exists (
      select 1 from work.&ds_dep. d
      where d.name=r.name and d.dep_nm=r.tok
    );

/* a variable may not depend on itself */
create table work.&ds_self. as
  select name, dep_nm from work.&ds_dep.
  where name=dep_nm;
quit;

%if "%upcase(&abort)"="NO" and %mf_nobs(work.&ds_baddep.)>0 %then %do;
  data &errds;
    set work.&ds_baddep.;
    length reason $200;
    reason=cats('VAR_DEPS lists ',dep_nm
      ,', which is not a column of the table or a derived variable');
    keep name reason;
  run;
  %return;
%end;

data _null_;
  set work.&ds_baddep.(obs=1);
  call symputx('derived_err'
    ,cats(name,': VAR_DEPS lists ',dep_nm
      ,', which is not a column of the table or a derived variable'));
run;

%mp_abort(iftrue= (0 < %mf_nobs(work.&ds_baddep.))
  ,mac=&sysmacroname
  ,msg=%superq(derived_err)
)

%if "%upcase(&abort)"="NO" and %mf_nobs(work.&ds_self.)>0 %then %do;
  data &errds;
    set work.&ds_self.;
    length reason $200;
    reason='VAR_DEPS may not list itself';
    keep name reason;
  run;
  %return;
%end;

data _null_;
  set work.&ds_self.(obs=1);
  call symputx('derived_err',cats(name,': VAR_DEPS may not list itself'));
run;

%mp_abort(iftrue= (0 < %mf_nobs(work.&ds_self.))
  ,mac=&sysmacroname
  ,msg=%superq(derived_err)
)

%if "%upcase(&abort)"="NO" and %mf_nobs(work.&ds_undecl.)>0 %then %do;
  data &errds;
    set work.&ds_undecl.;
    length reason $200;
    reason=cats('VAR_LOGIC references ',dep_nm,', which is not in VAR_DEPS');
    keep name reason;
  run;
  %return;
%end;

data _null_;
  set work.&ds_undecl.(obs=1);
  call symputx('derived_err'
    ,cats(name,': VAR_LOGIC references ',dep_nm
      ,', which is not in VAR_DEPS'));
run;

%mp_abort(iftrue= (0 < %mf_nobs(work.&ds_undecl.))
  ,mac=&sysmacroname
  ,msg=%superq(derived_err)
)

%if "%upcase(&abort)"="NO" and %mf_nobs(work.&ds_stale.)>0 %then %do;
  data &errds;
    set work.&ds_stale.;
    length reason $200;
    reason=cats('VAR_DEPS lists ',dep_nm,', which VAR_LOGIC does not'
      ,' reference');
    keep name reason;
  run;
  %return;
%end;

data _null_;
  set work.&ds_stale.(obs=1);
  call symputx('derived_err'
    ,cats(name,': VAR_DEPS lists ',dep_nm
      ,', which VAR_LOGIC does not reference'));
run;

%mp_abort(iftrue= (0 < %mf_nobs(work.&ds_stale.))
  ,mac=&sysmacroname
  ,msg=%superq(derived_err)
)

%if "%upcase(&abort)"="NO" and %mf_nobs(work.&ds_bad.)>0 %then %do;
  data &errds;
    set work.&ds_bad.(keep=name reason);
  run;
  %return;
%end;

data _null_;
  set work.&ds_bad.;
  putlog 'ERR' 'OR: derived variable config: ' name= reason=;
run;
data _null_;
  set work.&ds_bad.(obs=1);
  call symputx('derived_err',cats(name,': ',reason));
run;
%mp_abort(iftrue= (0 < %mf_nobs(work.&ds_bad.))
  ,mac=&sysmacroname
  ,msg=%str(Invalid derived variable configuration - &derived_err)
)

/**
  * Dependency order.  The edges are between derived variables only - a
  * physical column is available from the start.  Repeatedly take the variables
  * whose derived inputs have all been placed, alphabetically within a round;
  * if a round places nothing, what is left is a cycle.
  */
proc sql;
create table work.&ds_edge. as
  select d.name as child, d.dep_nm as parent
  from work.&ds_dep. d
  where d.dep_nm in (select name from work.&ds_byname.);
quit;

data work.&ds_todo.(keep=name);
  set work.&ds_byname.;
run;

data work.&ds_placed.(keep=name seq);
  length name $32;
  name='';
  seq=0;
  if 0;
run;

%let left=%mf_nobs(work.&ds_todo.);
%let nplaced=0;
%let cyc_found=0;

%do %while (&left>0);
  proc sql;
  create table work.&ds_ready. as
    select t.name
    from work.&ds_todo. t
    where not exists (
      select 1 from work.&ds_edge. e
      inner join work.&ds_todo. t2 on e.parent=t2.name
      where e.child=t.name
    )
    order by t.name;
  quit;

  %let nready=%mf_nobs(work.&ds_ready.);
  %if &nready=0 %then %do;
    /* walk the edges, so the message names the cycle rather than just the
      names that could not be placed */
    data _null_;
      set work.&ds_todo.(obs=1);
      call symputx('cyc_start',name);
    run;
    %let cyc_path=&cyc_start;
    %let cyc_cur=&cyc_start;
    %let cyc_seen=%str(.&cyc_start..);
    %do cyc_i=1 %to &left;
      %let cyc_next=;
      proc sql noprint;
        select e.parent into: cyc_next
        from work.&ds_edge. e
        where e.child="&cyc_cur"
          and e.parent in (select name from work.&ds_todo.);
      quit;
      %if %length(&cyc_next)=0 %then %let cyc_i=&left;
      %else %do;
        %let cyc_path=&cyc_path. -> &cyc_next;
        %if %index(&cyc_seen,%str(.&cyc_next..))>0 %then %let cyc_i=&left;
        %else %do;
          %let cyc_seen=&cyc_seen.&cyc_next..;
          %let cyc_cur=&cyc_next;
        %end;
      %end;
    %end;
    /* leave the loop before aborting - an abort cancels the step, and the
      loop would re-enter with the ready count still zero */
    %let cyc_found=1;
    %let left=0;
  %end;

  %if &cyc_found=0 %then %do;
    /* seq carries the dependency order - the placement rounds are not name
      ordered, so the final merge must not rely on by name alone */
    data work.&ds_ready.;
      set work.&ds_ready.;
      seq=_n_+&nplaced;
    run;
    proc append base=work.&ds_placed. data=work.&ds_ready. force;
    run;
    %let nplaced=%eval(&nplaced+&nready);

    proc sql;
    delete from work.&ds_todo.
      where name in (select name from work.&ds_ready.);
    quit;

    %let left=%mf_nobs(work.&ds_todo.);
  %end;
%end;

%if "%upcase(&abort)"="NO" and &cyc_found=1 %then %do;
  data &errds;
    length name $32 reason $200;
    name="&cyc_start";
    reason='VAR_DEPS contains a cycle';
    keep name reason;
  run;
  %return;
%end;

%mp_abort(iftrue= (&cyc_found=1)
  ,mac=&sysmacroname
  ,msg=%str(VAR_DEPS contains a cycle: &cyc_path)
)

proc sort data=work.&ds_placed.;
  by name;
run;

data work.&ds_srt.;
  merge work.&ds_placed.(in=in1) work.&ds_byname.(in=in2);
  by name;
  if in1 and in2;
run;

proc sort data=work.&ds_srt.;
  by seq;
run;

/**
  * Generate the attrib + assignment statements
  */
data _null_;
  file &outref;
  set work.&ds_srt.;
  /* 512 so the doubled quotes fit before the 256 boundary is applied */
  length stmt $4600 label $512 fmt2 $49;
  /* the configured label wins when there is one, otherwise the label is the
    name, an equals sign and the expression.  Labels are limited to 256 chars:
    the quotes are doubled first, then the cut is made on an even quote
    boundary - truncating between the two halves of an escape would leave the
    generated literal unterminated */
  if not missing(lbl) then label=lbl;
  else label=cats(name,'=',translate(logic,' ','0D0A'x));
  label=tranwrd(label,"'","''");
  if length(label)>256 then do;
    label=substr(label,1,256);
    if mod(count(label,"'"),2) ne 0 then label=substr(label,1,255);
  end;
  if not missing(fmt) and index(fmt,'.')=0 then fmt=cats(fmt,'.');
  if type='C' then do;
    if missing(fmt) then fmt2=cats('$',len,'.');
    else fmt2=fmt;
    stmt=catx(' ','attrib',name,cats('length=$',len)
      ,cats("label='",label,"'"),cats('format=',fmt2,';'));
  end;
  else do;
    if missing(fmt) then fmt2=cats(len,'.');
    else fmt2=fmt;
    stmt=catx(' ','attrib',name,cats('length=',len)
      ,cats("label='",label,"'"),cats('format=',fmt2,';'));
  end;
  put stmt;
  stmt=cats(name,' = ',logic,';');
  put stmt;
run;

%mp_abort(iftrue= (&syscc ne 0)
  ,mac=&sysmacroname
  ,msg=%str(Unable to generate derived variables for &libds)
)

data &outvars(keep=name);
  set work.&ds_srt.;
run;

%if %length(&outview)>0 and &outview ne 0 %then %do;
  data &outview / view=&outview;
    set &libds;
    %include &outref;
  run;
  %mp_abort(iftrue= (&syscc ne 0)
    ,mac=&sysmacroname
    ,msg=%str(Unable to build derived view &outview for &libds)
  )
%end;

%mend mp_derivedvars;
