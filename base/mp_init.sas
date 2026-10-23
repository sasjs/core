/**
  @file
  @brief Initialise session with useful settings and variables
  @details Implements a "strict" set of SAS options for use in defensive
    programming.  Highly recommended, if you want your code to run on some
    other machine.

    This macro is recommended to be compiled and invoked in the `initProgram`
    for SASjs [Jobs](https://cli.sasjs.io/sasjsconfig.html#jobConfig_initProgram
    ), [Services](
    https://cli.sasjs.io/sasjsconfig.html#serviceConfig_initProgram) and [Tests]
    (https://cli.sasjs.io/sasjsconfig.html#testConfig_initProgram).

    For non SASjs projects, you could invoke in the autoexec, or in your own
    solution initialisation macro.


    If you have a good idea for another useful option, setting, or global
    variable - feel free to [raise an issue](
    https://github.com/sasjs/core/issues/new)!

    All the system variables this macro creates use the hard-coded `_SASJS_`
    prefix - the same namespace sasjs/server uses in the pre-program it
    generates for each session (`_SASJS_WEBOUT_HEADERS`, `_SASJS_TOKENFILE`,
    `_SASJS_USERNAME` ...). There is no configurable prefix.

    Setting `_SASJS_INIT` before this macro runs skips it, which is how an
    autoexec opts out - a second pass would re-apply the options below.

  @version 9.2
  @author Allan Bowe

**/

%macro mp_init(
)/*/STORE SOURCE*/;

/* only run once. The guard is the marker: an autoexec that sets it is the
  documented way to skip this macro, and a second pass would re-apply the
  options below mid-session. SASJS_PREFIX is the name an existing autoexec
  would set, so it suppresses initialisation too. */
%if %symexist(_SASJS_INIT) or %symexist(SASJS_PREFIX) %then %return;

%global
  _SASJS_INIT        /* set to any value by this macro: "already initialised" */
  _SASJS_PROCESSMODE /* process mode, as the server's pre-program names it    */
  _SASJS_WEBOUT_HEADERS /* the server's webout header file location           */
  _SASJS_FUNCTIONS   /* used in mcf_init() to track core function compilation */
  _SASJS_INIT_NUM    /* initialisation time as numeric                        */
  _SASJS_INIT_DTTM   /* initialisation time in E8601DT26.6 format             */
  _SASJS_WORK        /* avoid typing %sysfunc(pathname(work)) every time      */
;
%let _sasjs_init=1;

data _null_;
  dttm=datetime();
  call symputx('_SASJS_INIT_NUM',dttm,'g');
  call symputx('_SASJS_INIT_DTTM',put(dttm,E8601DT26.6),'g');
  call symputx('_SASJS_WORK',pathname('WORK'),'g');
run;

options
  compress=CHAR           /* default is none so ensure we have something!   */
  datastmtchk=ALLKEYWORDS /* protection from overwriting input datasets     */
  errorcheck=STRICT       /* catch errs in libname/filename statements      */
  fmterr                  /* ensure err when a format cannot be found       */
  mergenoby=%str(ERR)OR   /* throw err when a merge has no BY variables     */
  missing=.               /* changing this can cause hard to detect errs    */
  noquotelenmax           /* avoid warnings for long strings                */
  noreplace               /* avoid overwriting permanent datasets           */
  ps=max                  /* reduce log size slightly                       */
  ls=max                  /* reduce log even more and avoid word truncation */
  validmemname=COMPATIBLE /* avoid special characters etc in table names    */
  validvarname=V7         /* avoid special characters etc in variable names */
  varinitchk=%str(ERR)OR  /* avoid data mistakes from variable name typos   */
  varlenchk=%str(ERR)OR   /* fail hard if truncation (data loss) can result */
%if "%substr(&sysver,1,1)" ne "4" and "%substr(&sysver,1,1)" ne "5" %then %do;
  noautocorrect           /* disallow misspelled procedure names            */
  dsoptions=note2err      /* undocumented - convert bad NOTEs to ERRs       */
                          /* turn off with dsoptions=nonote2err             */
%end;
;

%mend mp_init;
