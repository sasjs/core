/**
  @file mfv_getcaslib.sas
  @brief Returns the CAS caslib name for a given SAS libref
  @details Pure macro function.  Reads sashelp.vlibnam and returns
    the sysvalue where sysname='Caslib' for the given libref.  This
    is useful when the caslib name and libref name may differ.

    Usage:

        %put %mfv_getcaslib(lib=PUBLIC);

  @param [in] lib SAS libref for which to return the CAS caslib name

  @return Returns the CAS caslib name, or empty string if not found

**/

%macro mfv_getcaslib(lib);

%local dsid rc result;

%let dsid=%sysfunc(open(sashelp.vlibnam(
  where=(libname="%upcase(&lib)" and sysname="Caslib")
)));

%if &dsid %then %do;
  %let rc=%sysfunc(fetch(&dsid));
  %if &rc=0 %then
    %let result=%sysfunc(
      getvarc(&dsid,%sysfunc(varnum(&dsid,SYSVALUE)))
    );
  %let rc=%sysfunc(close(&dsid));
%end;

&result

%mend mfv_getcaslib;
