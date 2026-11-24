/**
  @file
  @brief Test directory listing DDL

  <h4> SAS Macros </h4>
  @li mddl_dirlist.sas
  @li mp_assert.sas
  @li mp_assertmodel.sas
  @li mp_assertscope.sas

**/

%mp_assertscope(SNAPSHOT)
%mddl_dirlist(work.dirlist_schema)
%mp_assertscope(COMPARE,desc=Directory DDL does not leak macro variables)
%mp_assert(iftrue=(%sysfunc(exist(work.dirlist_schema))=1),
  desc=Directory DDL creates the requested table)

/* Independent contract: do not derive the expected model from the DDL. */
data work.dirlist_expected;
  length directory filepath $2000 file_or_folder $6 filename $255 ext $20
    msg $200 level 8;
  call missing(of _all_);
  stop;
run;
%mp_assertmodel(work.dirlist_schema,base=work.dirlist_expected,
  desc=Directory DDL matches the canonical column contract)
