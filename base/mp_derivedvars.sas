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
  deterministic.  The label is the variable name, an equals sign, and the
  expression - so a reader can see both what the column is and where it comes
  from.

  Statements are generated in VAR_ORDER sequence, so a derived variable may
  reference another derived variable with a lower order.  A reference to a
  variable that is not defined earlier is rejected, because SAS would
  otherwise treat it as an uninitialised variable and return a missing value
  without an error.  Semicolons, macro triggers and comments are rejected, so
  a row can only ever be an expression.

  The control table is created by mddl_derivedvars.sas, and must carry LIBREF,
  DSN, VAR_NM, VAR_ORDER, VAR_TYPE, VAR_LEN, VAR_FMT and VAR_LOGIC.  Extra
  columns - such as a bitemporal TX_FROM / TX_TO pair - are ignored, and can be
  excluded with the where= clause.

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

%local physlist derived_err resv_list i w;

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
  length name $32 logic $4000 fmt $32;
  name=upcase(strip(var_nm));
  logic=strip(var_logic);
  type=upcase(strip(var_type));
  len=var_len;
  fmt=strip(upcase(var_fmt));
  ord=var_order;
run;

%if %mf_nobs(work.derived_cfg)=0 %then %return;

/* statement order is the configured order - a derived variable may reference
  one with a lower VAR_ORDER, so they must be assigned in this sequence */
proc sort data=work.derived_cfg out=work.derived_srt;
  by ord name;
run;

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
  set work.derived_srt;
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
  else if missing(ord) or ord ne int(ord) or ord<1
    then reason='VAR_ORDER must be a positive integer';
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

/* a derived variable may only reference derived variables defined earlier -
  otherwise the reference silently resolves to a missing value */
proc sql noprint;
create table work.derived_orderbad_key as
  select distinct a.name
  from work.derived_srt a
  inner join work.derived_srt b
    on a.name ne b.name
  where prxmatch(
      cats('/(^|[^A-Z0-9_])',b.name,'([^A-Z0-9_]|$)/')
      ,upcase(a.logic)
    )>0
    and b.ord>=a.ord
  order by a.name;
quit;

proc sort data=work.derived_orderbad_key;
  by name;
run;

data work.derived_orderbad;
  merge work.derived_byname(in=in1) work.derived_orderbad_key(in=in2);
  by name;
  if in2;
  length reason $200;
  reason='VAR_LOGIC references a derived variable that is not defined'
    !!' earlier - lower the VAR_ORDER of this one';
run;

proc append base=work.derived_bad data=work.derived_orderbad;
run;

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
