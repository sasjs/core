/**
  @file
  @brief Testing mp_include macro

  <h4> SAS Macros </h4>
  @li mp_include.sas
  @li mp_assert.sas

  @details mp_include is called from inside a macro here, which is the case it
  exists for.  The included file records the four _SYSINCLUDE* values it can
  see: they are created in the including scope for the duration of the include,
  which is what the macro documents and what the file asserts.

**/

filename incref temp;

data _null_;
  file incref;
  put 'data work.include_seen;';
  put '  length device name dir fref $300;';
  put '  device=symget("_SYSINCLUDEFILEDEVICE");';
  put '  name=symget("_SYSINCLUDEFILENAME");';
  put '  dir=symget("_SYSINCLUDEFILEDIR");';
  put '  fref=symget("_SYSINCLUDEFILEFILEREF");';
  put 'run;';
run;

%macro run_include_test();
  %mp_include(incref)
%mend run_include_test;

%run_include_test()

proc sql noprint;
  select count(*) into: n_rows from work.include_seen;
  select count(*) into: n_set from work.include_seen
    where length(device)>0 and length(name)>0 and length(dir)>0
      and fref='incref';
quit;

%mp_assert(
  iftrue=(&n_rows=1),
  desc=Checking that the included code is executed,
  outds=work.test_results
)

%mp_assert(
  iftrue=(&n_set=1),
  desc=Checking that the four _SYSINCLUDE values are visible to the include,
  outds=work.test_results
)
