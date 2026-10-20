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
  deterministic.  The label is the variable name, an equals sign and the
  expression - so a reader can see both what the column is and where it comes
  from.

  VAR_DEPENDENCIES lists every input the expression uses - physical columns
  and derived variables alike.  The order the statements are generated in is
  the dependency order (variables with no unsatisfied dependency first, ties
  broken by name), so a derived variable may build on another one without the
  administrator maintaining a sequence number.  A cycle is rejected.

  The declaration is checked against the expression: a derived variable that
  is referenced must be declared, a declared name that is not referenced is an
  error, and a declared name must be a column of the target table or a derived
  variable defined for it.  Semicolons, macro triggers and comments are
  rejected, so a row can only ever be an expression.

  The control table is created by mddl_derivedvars.sas, and must carry LIBREF,
  DSN, VAR_NM, VAR_DEPENDENCIES, VAR_TYPE, VAR_LEN, VAR_FMT and VAR_LOGIC.
  Extra columns - such as a bitemporal TX_FROM / TX_TO pair - are ignored, and
  can be excluded with the where= clause.

  <h4> SAS Macros </h4>
  @li mf_existds.sas
  @li mf_getvarlist.sas
  @li mf_nobs.sas
  @li mp_abort.sas

  <h4> Related Macros </h4>
  @li mddl_derivedvars.sas

  @param [in] libds= The target table (libref.dataset, lib must be assigned)
  @param [in] control= The control table holding the variable definitions
  @param [in] where= (0) Optional additional filter for the control table
  @param [out] outref= (0) Fileref to receive the generated statements
  @param [out] outvars= (work.derived_vars) Dataset of derived variable names
  @param [in] outview= (0) Optional two-level name for the derived view
  @param [in] reserved= (0) Space separated list of names that may not be used

  @version 5.6
  @author 4GL Apps Ltd
  @copyright 4GL Apps Ltd.  This code may only be used within Data Controller
    and may not be re-distributed or re-sold without the express permission of
    4GL Apps Ltd.

**/

%macro mp_derivedvars(libds=,
  control=,
  where=0,
  outref=0,
  outvars=work.derived_vars,
  outview=0,
  reserved=0
);

%local physlist derived_err resv_list i w left nready;

%mp_abort(iftrue= (%length(&libds)=0 or %length(&control)=0)
  ,mac=&sysmacroname
  ,msg=%str(Missing: libds control)
)
%mp_abort(iftrue= (&outref = 0)
  ,mac=&sysmacroname
  ,msg=%str(Please provide an outref for the generated statements)
)

filename &outref temp;

/* ensure the outputs exist, and are empty */
data _null_;
  file &outref;
run;
data &outvars(keep=name);
  length name $32;
  name='';
  if 0;
run;

%if %mf_existds(libds=&control) ne 1 %then %do;
  %put &sysmacroname: &control not found - no derived variables;
  %return;
%end;

data work.derived_cfg;
  set &control;
  %if "&where" ne "0" and %length(&where)>0 %then %do;
    where &where;
  %end;
  where also upcase(libref)="%upcase(%scan(&libds,1,.))"
    and upcase(dsn)="%upcase(%scan(&libds,2,.))";
  length name $32 logic $4000 fmt $32 deps $4000;
  name=upcase(strip(var_nm));
  logic=strip(var_logic);
  type=upcase(strip(var_type));
  len=var_len;
  fmt=strip(upcase(var_fmt));
  deps=upcase(strip(var_dependencies));
run;

%if %mf_nobs(work.derived_cfg)=0 %then %return;

proc sort data=work.derived_cfg out=work.derived_byname;
  by name;
run;

%let physlist=%upcase(%mf_getvarlist(&libds,dlm=%str(,),quote=SINGLE));

/* build a quoted list of reserved names, or an empty list */
%let resv_list=;
%if "&reserved" ne "0" %then %do i=1 %to %sysfunc(countw(&reserved,%str( )));
  %let w=%scan(&reserved,&i,%str( ));
  %let resv_list=&resv_list.%str(,)%str(%")%upcase(&w)%str(%");
%end;
%if %length(&resv_list)>0 %then %let resv_list=%substr(&resv_list,2);

/**
  * Reject anything that could break the generated data step, or that would
  * produce a variable we cannot describe to the caller
  */
data work.derived_bad;
  set work.derived_byname;
  length reason $200;
  call missing(reason);

  if name='' then reason='VAR_NM is required';
  else if verify(strip(name),'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_')>0
    then reason='VAR_NM must be a valid SAS name';
  else if verify(substr(name,1,1),'0123456789')=0
    then reason='VAR_NM must not start with a digit';
  else if name in (%unquote(&physlist))
    then reason='VAR_NM collides with a column in the target table';
  %if %length(&resv_list)>0 %then %do;
  else if name in (%unquote(&resv_list))
    then reason='VAR_NM is reserved';
  %end;
  else if type not in ('C','N')
    then reason='VAR_TYPE must be C or N';
  else if missing(len) or len ne int(len) or len<1
    then reason='VAR_LEN must be a positive integer';
  else if type='C' and len>32767
    then reason='VAR_LEN exceeds 32767 for a character variable';
  else if type='N' and len>8
    then reason='VAR_LEN exceeds 8 for a numeric variable';
  else if index(fmt,';')>0 or indexc(fmt,'&%')>0
    or index(fmt,'/*')>0 or index(fmt,'*/')>0
    then reason='VAR_FMT must be a format name, without ; & % or //*';
  else if verify(strip(fmt),'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_$.')>0
    then reason='VAR_FMT must be a format name';
  else if missing(logic)
    then reason='VAR_LOGIC is required';
  else if index(logic,';')>0
    then reason='VAR_LOGIC must be a single expression - remove the ;';
  else if indexc(logic,'&%')>0
    then reason='VAR_LOGIC must not contain macro triggers';
  else if index(logic,'/*')>0 or index(logic,'*/')>0
    then reason='VAR_LOGIC must not contain comments';

  if missing(reason)=0 then output;
run;

data work.derived_dup;
  set work.derived_byname;
  by name;
  length reason $200;
  if first.name and not last.name;
  reason='VAR_NM is defined more than once';
run;

proc append base=work.derived_bad data=work.derived_dup;
run;

/**
  * The declared dependencies, one row per word
  */
data work.derived_dep;
  set work.derived_byname;
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
data work.derived_ref;
  set work.derived_byname;
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
create table work.derived_bad_dep as
  select d.name, d.dep_nm
  from work.derived_dep d
  where d.dep_nm not in (%unquote(&physlist))
    and d.dep_nm not in (select name from work.derived_byname);

/* every declared name must actually appear in the expression */
create table work.derived_stale as
  select d.name, d.dep_nm
  from work.derived_dep d
  where not exists (
    select 1 from work.derived_ref r
    where r.name=d.name and r.tok=d.dep_nm
  );

/* a derived variable referenced by the expression must be declared, otherwise
  the statement order would be wrong and the value would be silently missing */
create table work.derived_undeclared as
  select distinct r.name, r.tok as dep_nm
  from work.derived_ref r
  where r.tok in (select name from work.derived_byname)
    and r.tok ne r.name
    and not exists (
      select 1 from work.derived_dep d
      where d.name=r.name and d.dep_nm=r.tok
    );

/* a variable may not depend on itself */
create table work.derived_self as
  select name, dep_nm from work.derived_dep
  where name=dep_nm;
quit;

%if %mf_nobs(work.derived_bad_dep)>0 %then %do;
  data _null_;
    set work.derived_bad_dep(obs=1);
    call symputx('derived_err'
      ,cats(name,': VAR_DEPENDENCIES lists ',dep_nm
        ,', which is not a column of the table or a derived variable'));
  run;
  %mp_abort(iftrue=1,mac=&sysmacroname,msg=%superq(derived_err))
%end;

%if %mf_nobs(work.derived_self)>0 %then %do;
  data _null_;
    set work.derived_self(obs=1);
    call symputx('derived_err',cats(name,': VAR_DEPENDENCIES may not list itself'));
  run;
  %mp_abort(iftrue=1,mac=&sysmacroname,msg=%superq(derived_err))
%end;

%if %mf_nobs(work.derived_undeclared)>0 %then %do;
  data _null_;
    set work.derived_undeclared(obs=1);
    call symputx('derived_err'
      ,cats(name,': VAR_LOGIC references ',dep_nm
        ,', which is not in VAR_DEPENDENCIES'));
  run;
  %mp_abort(iftrue=1,mac=&sysmacroname,msg=%superq(derived_err))
%end;

%if %mf_nobs(work.derived_stale)>0 %then %do;
  data _null_;
    set work.derived_stale(obs=1);
    call symputx('derived_err'
      ,cats(name,': VAR_DEPENDENCIES lists ',dep_nm
        ,', which VAR_LOGIC does not reference'));
  run;
  %mp_abort(iftrue=1,mac=&sysmacroname,msg=%superq(derived_err))
%end;

%if %mf_nobs(work.derived_bad)>0 %then %do;
  data _null_;
    set work.derived_bad;
    putlog 'ERR' 'OR: derived variable config: ' name= reason=;
  run;
  data _null_;
    set work.derived_bad(obs=1);
    call symputx('derived_err',cats(name,': ',reason));
  run;
  %mp_abort(iftrue=1
    ,mac=&sysmacroname
    ,msg=%str(Invalid derived variable configuration - &derived_err)
  )
%end;

/**
  * Dependency order.  The edges are between derived variables only - a
  * physical column is available from the start.  Repeatedly take the variables
  * whose derived inputs have all been placed, alphabetically within a round;
  * if a round places nothing, what is left is a cycle.
  */
proc sql;
create table work.derived_edge as
  select d.name as child, d.dep_nm as parent
  from work.derived_dep d
  where d.dep_nm in (select name from work.derived_byname);
quit;

data work.derived_todo(keep=name);
  set work.derived_byname;
run;

data work.derived_placed(keep=name);
  length name $32;
  name='';
  if 0;
run;

%let left=%mf_nobs(work.derived_todo);

%do %while (&left>0);
  proc sql;
  create table work.derived_ready as
    select t.name
    from work.derived_todo t
    where not exists (
      select 1 from work.derived_edge e
      inner join work.derived_todo t2 on e.parent=t2.name
      where e.child=t.name
    )
    order by t.name;
  quit;

  %let nready=%mf_nobs(work.derived_ready);
  %if &nready=0 %then %do;
    data _null_;
      length list $4000;
      do until (eof);
        set work.derived_todo end=eof;
        list=catx(', ',list,name);
      end;
      call symputx('derived_err',list);
    run;
    %mp_abort(iftrue=1
      ,mac=&sysmacroname
      ,msg=%str(VAR_DEPENDENCIES contains a cycle - unresolved: &derived_err)
    )
  %end;

  proc append base=work.derived_placed data=work.derived_ready force;
  run;

  proc sql;
  delete from work.derived_todo
    where name in (select name from work.derived_ready);
  quit;

  %let left=%mf_nobs(work.derived_todo);
%end;

data work.derived_srt;
  merge work.derived_placed(in=in1) work.derived_byname(in=in2);
  by name;
  if in1 and in2;
  seq=_n_;
run;

/**
  * Generate the attrib + assignment statements
  */
data _null_;
  file &outref;
  set work.derived_srt;
  length stmt $4100 label $256 fmt2 $49;
  /* labels cannot contain single quotes, and are limited to 256 chars */
  label=cats(name,'=',translate(logic,' ','0D0A'x));
  label=tranwrd(label,"'","''");
  label=substr(label,1,256);
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
  set work.derived_srt;
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
