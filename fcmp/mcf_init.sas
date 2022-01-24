/**
  @file
  @brief Sets up the mcf_xx functions
  @details
  There is no (efficient) way to determine if an mcf_xx macro has already been
  invoked.  So, we make use of a global macro variable list to keep track.

  Usage:

      %mcf_init(MCF_LENGTH)

  Returns:

  > 1 (if already initialised) else 0

  @param [in] func The function to be initialised

  <h4> Related Macros </h4>
  @li mcf_init.test.sas

**/

%macro mcf_init(func
)/*/STORE SOURCE*/;

%if not (%symexist(SASJS_PREFIX)) %then %do;
  %global SASJS_PREFIX;
  %let SASJS_PREFIX=SASJS;
%end;

%let func=%upcase(&func);

/* the / character is just a seperator */
%global &sasjs_prefix._FUNCTIONS;
%if %index(&&&sasjs_prefix._FUNCTIONS,&func/)>0 %then %do;
  1
  %return;
%end;
%else %do;
  %let &sasjs_prefix._FUNCTIONS=&&&sasjs_prefix._FUNCTIONS &func/;
  0
%end;

%mend mcf_init;
