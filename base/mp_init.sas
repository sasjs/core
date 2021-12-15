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

    All global variables are prefixed with "SASJS" (unless modified with the
    prefix parameter).

  @param [in] prefix= (SASJS) The prefix to apply to the global macro variables


  @version 9.2
  @author Allan Bowe

**/

%macro mp_init(prefix=
)/*/STORE SOURCE*/;

  %global
    &prefix._INIT_NUM   /* initialisation time as numeric             */
    &prefix._INIT_DTTM  /* initialisation time in E8601DT26.6 format */
  ;
  %if %eval(&&&prefix._INIT_NUM>0) %then %return;  /* only run once */

  data _null_;
    dttm=datetime();
    call symputx("&prefix._init_num",dttm);
    call symputx("&prefix._init_dttm",put(dttm,E8601DT26.6));
  run;

  options
    autocorrect             /* disallow mis-spelled procedure names           */
    compress=CHAR           /* default is none so ensure we have something!   */
    datastmtchk=ALLKEYWORDS /* protection from overwriting input datasets     */
    %str(err)orcheck=STRICT /* catch errs in libname/filename statements      */
    fmterr                  /* ensure err when a format cannot be found       */
    mergenoby=%str(ERR)OR   /* throw err when a merge has no BY variables     */
    missing=.               /* changing this can cause hard to detect errs    */
    noquotelenmax           /* avoid warnings for long strings                */
    noreplace               /* avoid overwriting permanent datasets           */
    ps=max                  /* reduce log size slightly                       */
    validmemname=COMPATIBLE /* avoid special characters etc in table names    */
    validvarname=V7         /* avoid special characters etc in variable names */
    varinitchk=%str(ERR)OR  /* avoid data mistakes from variable name typos   */
    varlenchk=%str(ERR)OR   /* fail hard if truncation (data loss) can result */
  ;

%mend mp_init;