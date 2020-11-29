/**
  @file
  @brief Checks whether a feature exists
  @details Check to see if a feature is supported in your environment.
    Run without arguments to see a list of detectable features.
    Note - this list is based on known versions of SAS rather than
    actual feature detection, as that is tricky / impossible to do
    without generating errors in most cases.

        %put %mf_existfeature(PROCLUA);

  @param feature the feature to detect.  Leave blank to list all in log.

  @return output returns 1 or 0 (or -1 if not found)

  <h4> Dependencies </h4>
  @li mf_getplatform.sas


  @version 8
  @author Allan Bowe
**/  /** @cond */

%macro mf_existfeature(feature
)/*/STORE SOURCE*/;
  %let feature=%upcase(&feature);
  %local platform;
  %let platform=%mf_getplatform();

  %if &feature= %then %do;
    %put Supported features:  PROCLUA;
  %end;
  %else %if &feature=PROCLUA %then %do;
    %if &platform=SASVIYA %then 1;
    %else %if "&sysver"="9.3" or "&sysver"="9.4" %then 1;
    %else 0;
  %end;
  %else %do;
    -1
    %put &sysmacroname: &feature not found;
  %end;
%mend;

/** @endcond */