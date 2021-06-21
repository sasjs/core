/**
  @file
  @brief Returns a character attribute of a dataset.
  @details Can be used in open code, eg as follows:

      %put Dataset label = %mf_getattrc(sashelp.class,LABEL);
      %put Member Type = %mf_getattrc(sashelp.class,MTYPE);

  @param libds library.dataset
  @param attr full list in [documentation](
    https://support.sas.com/documentation/cdl/en/lrdict/64316/HTML/default/viewer.htm#a000147794.htm)
  @return output returns result of the attrc value supplied, or -1 and log
    message if error.

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getattrc(
    libds
    ,attr
)/*/STORE SOURCE*/;
  %local dsid rc;
  %let dsid=%sysfunc(open(&libds,is));
  %if &dsid = 0 %then %do;
    %put %str(WARN)ING: Cannot open %trim(&libds), system message below;
    %put %sysfunc(sysmsg());
    -1
  %end;
  %else %do;
    %sysfunc(attrc(&dsid,&attr))
    %let rc=%sysfunc(close(&dsid));
  %end;
%mend mf_getattrc;