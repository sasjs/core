/**
  @file
  @brief Initialise session with useful settings and variables
  @details Implements a set of recommended options for general SAS use.  This
    macro is NOT used elsewhere within the core library (other than in tests),
    but it is used by the SASjs team when building web services for
    SAS-Powered applications elsewhere.

    If you have a good idea for an option, setting, or useful global variable -
    feel free to [raise an issue](https://github.com/sasjs/core/issues/new)!

    All global variables are prefixed with "SASJS_" (unless modfied with the
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
    errorcheck=STRICT       /* catch errors in libname/filename statements    */
    fmterr                  /* ensure err   when a format cannot be found     */
    mergenoby=%str(ERR)OR   /* Throw err   when a merge has no BY variables   */
    missing=.    /* some sites change this which causes hard to detect errors */
    noquotelenmax           /* avoid warnings for long strings                */
    noreplace               /* avoid overwriting permanent datasets           */
    ps=max                  /* reduce log size slightly                       */
    validmemname=COMPATIBLE /* avoid special characters etc in table names    */
    validvarname=V7         /* avoid special characters etc in variable names */
    varlenchk=%str(ERR)OR   /* fail hard if truncation (data loss) can result */
  ;

%mend mp_init;