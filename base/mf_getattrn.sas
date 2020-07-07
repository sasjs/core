/**
  @file
  @brief Returns a numeric attribute of a dataset.
  @details Can be used in open code, eg as follows:

      %put Number of observations=%mf_getattrn(sashelp.class,NLOBS);
      %put Number of variables = %mf_getattrn(sashelp.class,NVARS);

  @param libds library.dataset
  @param attr Common values are NLOBS and NVARS, full list in [documentation](
    http://support.sas.com/documentation/cdl/en/lrdict/64316/HTML/default/viewer.htm#a000212040.htm)
  @return output returns result of the attrn value supplied, or -1 and log
    message if error.

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getattrn(
     libds
    ,attr
)/*/STORE SOURCE*/;
  %local dsid rc;
  %let dsid=%sysfunc(open(&libds,is));
  %if &dsid = 0 %then %do;
    %put WARNING: Cannot open %trim(&libds), system message below;
    %put %sysfunc(sysmsg());
    -1
  %end;
  %else %do;
    %sysfunc(attrn(&dsid,&attr))
    %let rc=%sysfunc(close(&dsid));
  %end;
%mend;