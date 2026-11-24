/**
  @file
  @brief Test directory listing DDL

  <h4> SAS Macros </h4>
  @li mddl_dirlist.sas
  @li mp_assert.sas
  @li mp_assertscope.sas

**/

%mp_assertscope(SNAPSHOT)
%mddl_dirlist(work.dirlist_schema)
%mp_assertscope(COMPARE,desc=Directory DDL does not leak macro variables)
%mp_assert(iftrue=(%sysfunc(exist(work.dirlist_schema))=1),
  desc=Directory DDL creates the requested table)
