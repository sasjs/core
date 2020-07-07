/**
  @file
  @brief Retrieves a value from a dataset.  If no filter supplied, then first
    record is used.
  @details Be sure to <code>%quote()</code> your where clause.  Example usage:

      %put %mf_getvalue(sashelp.class,name,filter=%quote(age=15));
      %put %mf_getvalue(sashelp.class,name);

  <h4> Dependencies </h4>
  @li mf_getattrn.sas

  @param libds dataset to query
  @param variable the variable which contains the value to return.
  @param filter contents of where clause

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getvalue(libds,variable,filter=1
)/*/STORE SOURCE*/;
 %if %mf_getattrn(&libds,NLOBS)>0 %then %do;
    %local dsid rc &variable;
    %let dsid=%sysfunc(open(&libds(where=(&filter))));
    %syscall set(dsid);
    %let rc = %sysfunc(fetch(&dsid));
    %let rc = %sysfunc(close(&dsid));

    %trim(&&&variable)

  %end;
%mend;