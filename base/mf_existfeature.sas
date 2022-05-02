/**
  @file
  @brief Checks whether a feature exists
  @details Check to see if a feature is supported in your environment.
    Run without arguments to see a list of detectable features.
    Note - this list is based on known versions of SAS rather than
    actual feature detection, as that is tricky / impossible to do
    without generating errs in most cases.

        %put %mf_existfeature(PROCLUA);

  @param [in] feature The feature to detect.

  @return output returns 1 or 0 (or -1 if not found)

  <h4> SAS Macros </h4>
  @li mf_getplatform.sas

  @version 8
  @author Allan Bowe
**/
/** @cond */
%macro mf_existfeature(feature
)/*/STORE SOURCE*/;
  %let feature=%upcase(&feature);
  %local platform;
  %let platform=%mf_getplatform();

  %if &feature= %then %do;
    %put No feature was requested for detection;
  %end;
  %else %if &feature=COLCONSTRAINTS %then %do;
    %if "%substr(&sysver,1,1)"="4" or "%substr(&sysver,1,1)"="5" %then 0;
    %else 1;
  %end;
  %else %if &feature=PROCLUA %then %do;
    /* https://blogs.sas.com/content/sasdummy/2015/08/03/using-lua-within-your-sas-programs */
    %if &platform=SASVIYA %then 1;
    %else %if "&sysver"="9.2" or "&sysver"="9.3" %then 0;
    %else %if "&SYSVLONG" < "9.04.01M3" %then 0;
    %else 1;
  %end;
  %else %do;
    -1
    %put &sysmacroname: &feature not found;
  %end;
%mend mf_existfeature;
/** @endcond */
