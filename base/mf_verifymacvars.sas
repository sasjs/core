/**
  @file
  @brief Checks if a set of macro variables exist AND contain values.
  @details Reports a failure in the log and returns 0.  It never aborts: an
  mf_ macro returns a value, and ending the step here would leave the caller
  unable to see that value or to report the failure itself.
  Usage:

      %let var1=x;
      %let var2=y;
      %put %mf_verifymacvars(var1 var2);

  Returns:
  > 1

  @param [in] verifyvars Space separated list of macro variable names
  @param [in] makeupcase= (NO) Set to YES to convert all variable VALUES to
    uppercase.
  @param [in] mAbort= (SOFT) Retained for backwards compatibility.  The macro
    no longer aborts on any value - a failure is written to the log and 0 is
    returned, so the caller decides what to do with it.

  @note will not be able to verify the following variables due to
    naming clash!
      - verifyVars
      - verifyVar
      - verifyIterator
      - makeUpcase

  @version 9.2
  @author Allan Bowe

**/

%macro mf_verifymacvars(
    verifyVars  /* list of macro variable NAMES */
    ,makeUpcase=NO  /* set to YES to make all the variable VALUES uppercase */
    ,mAbort=SOFT
)/*/STORE SOURCE*/;

  %local verifyIterator verifyVar abortmsg;
  %do verifyIterator=1 %to %sysfunc(countw(&verifyVars,%str( )));
    %let verifyVar=%qscan(&verifyVars,&verifyIterator,%str( ));
    %if not %symexist(&verifyvar) %then %do;
      %let abortmsg= Variable &verifyVar is MISSING;
      %goto exit_err;
    %end;
    %if %length(%trim(&&&verifyVar))=0 %then %do;
      %let abortmsg= Variable &verifyVar is EMPTY;
      %goto exit_err;
    %end;
    %if &makeupcase=YES %then %do;
      %let &verifyVar=%upcase(&&&verifyvar);
    %end;
  %end;

  %goto exit_success;
  %exit_err:
    %put &abortmsg;
    0
    %return;
  %exit_success:
  1

%mend mf_verifymacvars;
