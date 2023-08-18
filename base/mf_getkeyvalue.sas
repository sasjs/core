/**
  @file
  @brief retrieves a key value pair from a control dataset
  @details By default, control dataset is work.mp_setkeyvalue.  Usage:

      %mp_setkeyvalue(someindex,22,type=N)
      %put %mf_getkeyvalue(someindex)


  @param [in] key Provide a key on which to perform the lookup
  @param [in] libds= (work.mp_setkeyvalue) The library.dataset which holds the
    parameters

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getkeyvalue(key,libds=work.mp_setkeyvalue
)/*/STORE SOURCE*/;
%local ds dsid key valc valn type rc;
%let dsid=%sysfunc(open(&libds(where=(key="&key"))));
%syscall set(dsid);
%let rc = %sysfunc(fetch(&dsid));
%let rc = %sysfunc(close(&dsid));

%if &type=N %then %do;
  &valn
%end;
%else %if &type=C %then %do;
  &valc
%end;
%else %put %str(ERR)OR: Unable to find key &key in ds &libds;
%mend mf_getkeyvalue;