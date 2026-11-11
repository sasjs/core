/**
  @file
  @brief Testing ml_json macro
  @details ml_json writes json.lua to the work directory and includes it, so a
    test needs no Lua source of its own: the artefact is the file, and the
    include is proven by the syscc check. The suite runs with options lrecl=80,
    which is narrow enough to truncate the library's wider lines as they are
    written - the macro widens the option for the write as well as the include.

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas
  @li ml_json.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%let lua_syscc=0;
%let lua_marker=0;
%let luapath=%sysfunc(pathname(work))/ml_json.lua;

%mp_assertscope(SNAPSHOT)
%ml_json()
%let lua_syscc=&syscc;
%mp_assertscope(COMPARE,
  desc=ml_json does not leak scope,
  outds=work.test_results
)

%let lua_exists=%sysfunc(fileexist(&luapath));

%let fref=%mf_getuniquefileref();
filename &fref "&luapath";
data _null_;
  infile &fref lrecl=1024 end=eof;
  input line $char1024.;
  /* a wide line from the middle of the library - it is the one a narrow
    LRECL loses, so finding it proves the whole file was written */
  if index(line,'copies or substantial portions of the Software')
    then call symputx('lua_marker',1,'l');
run;

%mp_assert(
  iftrue=(&lua_exists=1),
  desc=Check json.lua was written to the work directory
)
%mp_assert(
  iftrue=(&lua_marker=1),
  desc=Check the file carries the whole json library
)
%mp_assert(
  iftrue=(&lua_syscc=0),
  desc=Check including the lua file leaves syscc clean
)
