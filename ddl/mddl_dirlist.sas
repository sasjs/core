/**
  @file
  @brief DDL for the fixed directory listing columns
  @details Creates an empty table with the names, types and lengths used by
  mp_dirlist. The table must not already exist.

  Example:

      %mddl_dirlist(work.dirlist_schema)

  @param [in] libds Required table to create

  <h4> Related Macros </h4>
  @li mp_dirlist.sas

  @version 9.2
  @author sasjs@4gl.io
**/

%macro mddl_dirlist(libds);
  %if %sysevalf(%superq(libds)=,boolean) %then %do;
    %put %str(ERR)OR: MDDL_DIRLIST requires a table name.;
    %let syscc=%sysfunc(max(&syscc,1012));
    %return;
  %end;

  proc sql;
    create table &libds( directory char(2000), filepath char(2000),
      file_or_folder char(6), filename char(255), ext char(20),
      msg char(200), level num );
  quit;
%mend mddl_dirlist;
