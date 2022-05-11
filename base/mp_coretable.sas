/**
  @file
  @brief Create the permanent Core tables
  @details Several macros in the [core](https://github.com/sasjs/core) library
    make use of permanent tables.  To avoid duplication in definitions, this
    macro provides a central location for managing the corresponding DDL.

  Note - this macro is likely to be deprecated in future in favour of a
  dedicated "datamodel" folder (prefix mddl)

  Any corresponding data would go in a seperate repo, to avoid this one
  ballooning in size!

  Example usage:

      %mp_coretable(LOCKTABLE,libds=work.locktable)

  @param [in] table_ref The type of table to create.  Example values:
    @li DIFFTABLE
    @li FILTER_DETAIL
    @li FILTER_SUMMARY
    @li LOCKANYTABLE
    @li MAXKEYTABLE
  @param [in] libds= (0) The library.dataset reference used to create the table.
    If not provided, then the DDL is simply printed to the log.

  <h4> SAS Macros </h4>
  @li mddl_dc_difftable.sas
  @li mddl_dc_filterdetail.sas
  @li mddl_dc_filtersummary.sas
  @li mddl_dc_locktable.sas
  @li mddl_dc_maxkeytable.sas

  <h4> Related Macros </h4>
  @li mp_filterstore.sas
  @li mp_lockanytable.sas
  @li mp_retainedkey.sas
  @li mp_storediffs.sas
  @li mp_stackdiffs.sas

  @version 9.2
  @author Allan Bowe

**/

%macro mp_coretable(table_ref,libds=0
)/*/STORE SOURCE*/;
%local outds ;
%let outds=%sysfunc(ifc(&libds=0,_data_,&libds));
proc sql;
%if &table_ref=DIFFTABLE %then %do;
  %mddl_dc_difftable(libds=&outds)
%end;
%else %if &table_ref=LOCKTABLE %then %do;
  %mddl_dc_locktable(libds=&outds)
%end;
%else %if &table_ref=FILTER_SUMMARY %then %do;
  %mddl_dc_filtersummary(libds=&outds)
%end;
%else %if &table_ref=FILTER_DETAIL %then %do;
  %mddl_dc_filterdetail(libds=&outds)
%end;
%else %if &table_ref=MAXKEYTABLE %then %do;
  %mddl_dc_maxkeytable(libds=&outds)
%end;

%if &libds=0 %then %do;
  proc sql;
  describe table &syslast;
  drop table &syslast;
%end;
%mend mp_coretable;
