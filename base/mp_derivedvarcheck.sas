/**
  @file
  @brief Validates derived variable definitions, one row per rule
  @details Reads a table of derived variable definitions and writes one row per
  definition that breaks a rule, with the reason in REASON.  Nothing is
  executed, no view is built and no target table is needed: the macro is a
  scan of definitions, so it can run at submit time - or against any table of
  expressions in a code scanning tool - long before the definitions are used.

  The input is the shape a control table carries, which is the shape
  mddl_derivedvars.sas creates:

  @li VAR_NM - the name of the variable to create
  @li VAR_TYPE - C or N
  @li VAR_LEN - a positive integer, at most 32767 for character and 8 for
    numeric
  @li VAR_FMT - an optional format name
  @li VAR_LOGIC - the expression, which must be a single expression with no
    macro triggers and no comments, at most 4000 characters - the limit of the
    statement buffer and of the control table, so a longer value would be cut
    down silently
  @li VAR_LABEL - optional, plain text of at most 256 characters

  Extra columns are ignored, so a caller can scan the control table itself, a
  staged submission, or a table of expressions assembled from a program.

  <h4>Why a function name is refused and a character is not</h4>

  VAR_LOGIC is concatenated into a generated assignment, so an expression that
  can submit a program of its own (DOSUBL) or reach the file system, the
  environment or the macro symbol table is a way into the session.  Blocked
  characters cannot cover that: BYTE(59) builds the semicolon at run time, so
  a payload carries no blocked character in its source text - while the name of
  the function it calls is part of the expression this scan reads, and cannot
  be constructed.  Quoted literals are removed before the check, so a refused
  word that is only data is not read as a call.

  The refused names are DOSUBL, JAVAOBJ, JAVAMETA, SYMGET, SYMPUT, SYMPUTX,
  SYSGET, GETOPTION, PATHNAME, FILEEXIST, FOPEN, FREAD, FGET, FCLOSE, DOPEN,
  DREAD, DNUM, MOPEN and SLEEP.  Add your own with denyfuncs=.

  <h4> SAS Macros </h4>
  @li mf_existds.sas
  @li mf_existvar.sas
  @li mp_abort.sas

  <h4> Related Macros </h4>
  @li mp_derivedvars.sas
  @li mddl_derivedvars.sas

  @param [in] inds= The definitions to check
  @param [out] outds= (work.dv_check) One row per definition that breaks a
    rule: NAME (the upcased VAR_NM) and REASON.  Empty when every row is valid
  @param [in] physlist= (0) Space separated list of the columns of the target
    table, unquoted and case insensitive - what %mf_getvarlist(&libds) returns.
    Supplied, a VAR_NM that collides with one of them is refused; when the
    target is not at hand, leave it at 0 and that rule is not applied
  @param [in] reserved= (0) Space separated list of names that may not be used
  @param [in] denyfuncs= (0) Space separated list of further function names to
    refuse, for a site that allows more of the SAS vocabulary than the default

  @version 1.0
  @author 4GL Apps Ltd

**/

%macro mp_derivedvarcheck(inds=,
  outds=work.dv_check,
  physlist=0,
  reserved=0,
  denyfuncs=0
);

%local deny denycnt physcnt resv_list phys_list i w;

%mp_abort(iftrue= (%length(&inds)=0)
  ,mac=&sysmacroname
  ,msg=%str(Please provide the definitions to check in inds)
)
%mp_abort(iftrue= (%mf_existds(libds=&inds) ne 1)
  ,mac=&sysmacroname
  ,msg=%str(Definitions not found: &inds)
)

/* the capabilities that are refused - a function name cannot be assembled at
  run time, so naming them is a control the expression cannot evade */
%let deny=DOSUBL|JAVAOBJ|JAVAMETA|SYMGET|SYMPUTX?|SYSGET|GETOPTION;
%let deny=&deny.|PATHNAME|FILEEXIST|FOPEN|FREAD|FGET|FCLOSE;
%let deny=&deny.|DOPEN|DREAD|DNUM|MOPEN|SLEEP;
%let denycnt=%sysfunc(countw(&denyfuncs,%str( )));
%if "%upcase(&denyfuncs)" ne "0" %then %do i=1 %to &denycnt;
  %let deny=&deny.|%upcase(%scan(&denyfuncs,&i,%str( )));
%end;

/* the target columns, as a quoted list - supplied only when the caller has the
  table to hand */
%let phys_list=;
%let physcnt=%sysfunc(countw(&physlist,%str( )));
%if %length(&physlist)>0 and "%upcase(&physlist)" ne "0"
  %then %do i=1 %to &physcnt;
  %let w=%scan(&physlist,&i,%str( ));
  %let phys_list=&phys_list.%str(,)%str(%")%upcase(&w)%str(%");
%end;
%if %length(&phys_list)>0 %then %let phys_list=%substr(&phys_list,2);

/* build a quoted list of reserved names, or an empty list */
%let resv_list=;
%if "&reserved" ne "0" %then %do i=1 %to %sysfunc(countw(&reserved,%str( )));
  %let w=%scan(&reserved,&i,%str( ));
  %let resv_list=&resv_list.%str(,)%str(%")%upcase(&w)%str(%");
%end;
%if %length(&resv_list)>0 %then %let resv_list=%substr(&resv_list,2);

data &outds(keep=name reason);
  set &inds;
  length name $32 reason $200 l $4000;
  call missing(reason);
  name=upcase(strip(var_nm));

  /* quoted literals are data, not calls - strip them before the vocabulary
    check so a label or a value that names a refused function is allowed */
  l=prxchange("s/'([^']|'')*'//",-1,var_logic);
  l=prxchange('s/\"([^\"]|\"\")*\"//',-1,l);

  if name='' then reason='VAR_NM is required';
  else if verify(strip(name),'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_')>0
    then reason='VAR_NM must be a valid SAS name';
  else if verify(substr(name,1,1),'0123456789')=0
    then reason='VAR_NM must not start with a digit';
  else if name in ('_N_','_ERROR_','_IORC_')
    then reason='VAR_NM is an automatic variable of the data step';
  %if %length(&phys_list)>0 %then %do;
  else if name in (%unquote(&phys_list))
    then reason='VAR_NM collides with a column in the target table';
  %end;
  %if %length(&resv_list)>0 %then %do;
  else if name in (%unquote(&resv_list))
    then reason='VAR_NM is reserved';
  %end;
  else if upcase(strip(var_type)) not in ('C','N')
    then reason='VAR_TYPE must be C or N';
  else if missing(var_len) or var_len ne int(var_len) or var_len<1
    then reason='VAR_LEN must be a positive integer';
  else if upcase(strip(var_type))='C' and var_len>32767
    then reason='VAR_LEN exceeds 32767 for a character variable';
  else if upcase(strip(var_type))='N' and var_len>8
    then reason='VAR_LEN exceeds 8 for a numeric variable';
  else if index(var_fmt,';')>0 or indexc(var_fmt,'&%')>0
    or index(var_fmt,'/*')>0 or index(var_fmt,'*/')>0
    then reason='VAR_FMT must be a format name, without ; & % or /* */';
  else if verify(strip(upcase(var_fmt))
      ,'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_$.')>0
    then reason='VAR_FMT must be a format name';
  %if %mf_existvar(&inds,VAR_LABEL) gt 0 %then %do;
  /* VAR_LABEL is free text - any script, any character - because the quotes
    in it are escaped when the attrib statement is built.  What cannot be a
    single line column label is a control character or a line break */
  else if anycntrl(var_label)>0
    then reason='VAR_LABEL must be plain text - no line breaks or'
      ||' control characters';
  else if klength(var_label)>256
    then reason='VAR_LABEL exceeds 256 characters';
  %end;
  else if missing(var_logic)
    then reason='VAR_LOGIC is required';
  else if klength(var_logic)>4000
    then reason='VAR_LOGIC exceeds 4000 characters';
  else if index(var_logic,';')>0
    then reason='VAR_LOGIC must be a single expression - remove the ;';
  else if indexc(var_logic,'&%')>0
    then reason='VAR_LOGIC must not contain macro triggers';
  else if index(var_logic,'/*')>0 or index(var_logic,'*/')>0
    then reason='VAR_LOGIC must not contain comments';
  else if prxmatch("/\b(&deny)\s*\(/",upcase(l))>0
    then reason='VAR_LOGIC may not call a function that submits code or'
      ||' reaches the file system, the environment or the macro symbol table';

  if missing(reason)=0 then output;
run;

%mend mp_derivedvarcheck;
