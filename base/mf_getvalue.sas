/**
  @file
  @brief Retrieves a value from a dataset. Returned value is fetched from the
  'fetchobs=' record (row 1 by default), after applying the optional filter.

  @details Be sure to <code>%quote()</code> your where clause.  Example usage:

      %put %mf_getvalue(sashelp.class,name,filter=%quote(age=15));
      %put %mf_getvalue(sashelp.class,name);

  <h4> SAS Macros </h4>
  @li mf_getattrn.sas

  <h4> Related Macros </h4>
  @li mp_setkeyvalue.sas

  @param [in] libds dataset to query
  @param [in] variable the variable which contains the value to return.
  @param [in] filter= (1) contents of where clause
  @param [in] fetchobs= (1) observation to fetch. NB: Filter applies first.

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getvalue(libds,variable,filter=1,fetchobs=1
)/*/STORE SOURCE*/;
  %local dsid;

  %let dsid=%sysfunc(open(&libds(where=(&filter))));
  %if (&dsid) %then %do;
    %local rc &variable;
    %syscall set(dsid);
    %let rc = %sysfunc(fetchobs(&dsid,&fetchobs));
    %if (&rc ne 0) %then %do;
      %put NOTE: Problem reading obs &fetchobs from &libds..;
      %put %sysfunc(sysmsg());
      /* Coerce an rc value of -1 (read past end of data) to a 4
      that, in SAS condition code terms, represents the sysmsg
      w@rning it generates. */
      %if &rc eq -1 %then %let rc = 4;
      /* And update SYSCC if the &rc value is higher */
      %let syscc = %sysfunc(max(&syscc,&rc));
    %end;
    %let rc = %sysfunc(close(&dsid));

    %trim(&&&variable)

  %end;
  %else %do;
    %put %sysfunc(sysmsg());
    %let syscc = %sysfunc(max(&syscc,%sysfunc(sysrc())));
  %end;

%mend mf_getvalue;
