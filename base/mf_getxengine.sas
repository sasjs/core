/**
  @file
  @brief Returns the engine type of a SAS fileref
  @details Queries sashelp.vextfl to get the xengine value.
  Usage:

      filename feng temp;
      %put %mf_getxengine(feng);

  returns:
  > TEMP

  @param [in] fref The fileref to check

  @returns The XENGINE value in sashelp.vextfl. A fileref that has a row there
    but no XENGINE value - including a fileref that is not assigned - returns
    an empty string; 0 is returned only when sashelp.vextfl cannot be opened.

  @version 9.2
  @author Allan Bowe

  <h4> Related Macros </h4>
  @li mf_getengine.sas

**/

%macro mf_getxengine(fref
)/*/STORE SOURCE*/;
  %local dsid engnum rc engine;

  %let dsid=%sysfunc(
    open(sashelp.vextfl(where=(fileref="%upcase(&fref)")),i)
  );
  %if (&dsid ^= 0) %then %do;
    %let engnum=%sysfunc(varnum(&dsid,XENGINE));
    %let rc=%sysfunc(fetch(&dsid));
    %let engine=%sysfunc(getvarc(&dsid,&engnum));
    %* put &fref. ENGINE is &engine.;
    %let rc= %sysfunc(close(&dsid));
  %end;
  %else %let engine=0;

  &engine

%mend mf_getxengine;
