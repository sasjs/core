/**
  @file
  @brief DDL for the shared group model
  @details Creates an empty table with the names, types and lengths returned by
  the group listing macros. The table must not already exist.

  Example:

      %mddl_getgroups(work.group_schema)

  @param [in] libds Required table to create

  <h4> Related Macros </h4>
  @li mm_getgroups.sas
  @li ms_getgroups.sas
  @li mv_getgroups.sas
  @li mx_getgroups.sas

  @version 9.2
  @author sasjs@4gl.io
**/

%macro mddl_getgroups(libds);
  %if %sysevalf(%superq(libds)=,boolean) %then %do;
    %put %str(ERR)OR: MDDL_GETGROUPS requires a table name.;
    %let syscc=%sysfunc(max(&syscc,1012));
    %return;
  %end;

  proc sql;
    create table &libds( groupuri char(256), groupname char(256),
      groupdesc char(256) );
  quit;
%mend mddl_getgroups;
