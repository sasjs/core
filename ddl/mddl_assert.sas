/**
  @file
  @brief DDL for assertion results
  @details Creates an empty table with the column names, types and lengths
  used for assertion results. The table must not already exist.
  The mp_assert macros use this DDL for their result rows.

  Example:

      %mddl_assert(work.assertions)

  @param [in] libds Required table to create

  <h4> Related Macros </h4>
  @li mp_assert.sas
  @li mp_assertmodel.sas

  @version 9.4
  @author sasjs@4gl.io
**/

%macro mddl_assert(libds);
  %if %sysevalf(%superq(libds)=,boolean) %then %do;
    %put %str(ERR)OR: MDDL_ASSERT requires a table name.;
    %let syscc=%sysfunc(max(&syscc,1012));
    %return;
  %end;

  proc sql;
    create table &libds( test_description char(256), test_result char(5),
      test_comments char(256) );
  quit;
%mend mddl_assert;
