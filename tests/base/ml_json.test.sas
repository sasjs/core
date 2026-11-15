/**
  @file
  @brief Testing ml_json macro
  @details ml_json writes json.lua to the work directory and includes it, so a
    test needs no Lua source of its own: the artefact is the file. The suite
    runs with options lrecl=80, which is narrow enough to truncate the
    library's wider lines as they are written, so a file that keeps records
    longer than 80 characters proves the write ran under the wide LRECL the
    macro sets, and a clean syscc proves the include worked.

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li ml_json.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

/* ml_json writes a 375-line DATA step, and echoing it (plus MPRINT from the
  suite's _debug URL) fills the engine's job log past its limit - the job is
  then aborted before the term program returns a result.  Quiet the source
  echo for this file; the assertions are PUT output, which is unaffected. */
options nosource nomprint;

%let luapath=%sysfunc(pathname(work))/ml_json.lua;
%let lua_exists=0;
%let lua_marker=0;
%let lua_syscc=0;

%mp_assertscope(SNAPSHOT)
%ml_json()
%let lua_syscc=&syscc;
%mp_assertscope(COMPARE,
  desc=ml_json does not leak scope,
  ignorelist=LUA_SYSCC,
  outds=work.test_results
)

%let lua_exists=%sysfunc(fileexist(&luapath));
%let fref=%mf_getuniquefileref();
filename &fref "&luapath";
data _null_;
  infile &fref lrecl=1024 end=eof;
  input line $char1024.;
  /* a record longer than 80 characters cannot exist in a file written under
    lrecl=80, so finding one proves the wide setting was in force */
  if length(line)>80 then call symputx('lua_marker',1,'l');
run;

%mp_assert(
  iftrue=(&lua_exists=1),
  desc=Check json.lua was written to the work directory
)
%mp_assert(
  iftrue=(&lua_marker=1),
  desc=Check the file keeps records wider than 80 characters
)
%mp_assert(
  iftrue=(&lua_syscc=0),
  desc=Check including the lua file leaves syscc clean
)
