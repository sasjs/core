/**
  @file mf_getplatform.sas
  @brief Returns platform specific variables
  @details Enables platform specific variables to be returned

      %put %mf_getplatform();

  returns one of:

  @li SASMETA
  @li SASVIYA
  @li SASJS
  @li BASESAS

  @param switch the param for which to return a platform specific variable

  <h4> SAS Macros </h4>
  @li mf_mval.sas
  @li mf_trimstr.sas

  @version 9.4 / 3.4
  @author Allan Bowe
**/

%macro mf_getplatform(switch
)/*/STORE SOURCE*/;
%local a b c;
%if &switch.NONE=NONE %then %do;
  %if %symexist(sasjsprocessmode) %then %do;
    %if &sasjsprocessmode=Stored Program %then %do;
      SASJS
      %return;
    %end;
  %end;
  %if %symexist(sysprocessmode) %then %do;
    %if "&sysprocessmode"="SAS Object Server"
    or "&sysprocessmode"= "SAS Compute Server" %then %do;
        SASVIYA
    %end;
    %else %if "&sysprocessmode"="SAS Stored Process Server"
      or "&sysprocessmode"="SAS Workspace Server"
    %then %do;
      SASMETA
      %return;
    %end;
    %else %do;
      BASESAS
      %return;
    %end;
  %end;
  %else %if %symexist(_metaport) or %symexist(_metauser) %then %do;
    SASMETA
    %return;
  %end;
  %else %do;
    BASESAS
    %return;
  %end;
%end;
%else %if &switch=SASSTUDIO %then %do;
  /* return the version of SAS Studio else 0 */
  %if %mf_mval(_CLIENTAPP)=%str(SAS Studio) %then %do;
    %let a=%mf_mval(_CLIENTVERSION);
    %let b=%scan(&a,1,.);
    %if %eval(&b >2) %then %do;
      &b
    %end;
    %else 0;
  %end;
  %else 0;
%end;
%else %if &switch=VIYARESTAPI %then %do;
  %mf_trimstr(%sysfunc(getoption(servicesbaseurl)),/)
%end;
%mend mf_getplatform;
