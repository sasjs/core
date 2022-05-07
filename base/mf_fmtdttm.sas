/**
  @file
  @brief Returns E8601DT26.6 if compatible else DATETIME19.3
  @details From our experience in [Data Controller for SAS]
  (https://datacontroller.io) deployments, the E8601DT26.6 datetime format has
  the widest support when it comes to pass-through SQL queries.

  However, it is not supported in WPS or early versions of SAS 9 (M3 and below)
  when used as a datetime literal, eg:

      data _null_;
        demo="%sysfunc(datetime(),E8601DT26.6)"dt;
        demo=;
      run;

  This macro will therefore return DATEITME19.3 as an alternative format
  based on the runtime environment so that it can be used in such cases, eg:

      data _null_;
        demo="%sysfunc(datetime(),%mf_fmtdttm())"dt;
        demo=;
      run;

  <h4> Related Macros </h4>
  @li mf_fmtdttm.test.sas

  @author Allan Bowe
**/

%macro mf_fmtdttm(
)/*/STORE SOURCE*/;

%if "&sysver"="9.2" or "&sysver"="9.3"
  or ("&sysver"="9.4" and "%substr(&SYSVLONG,9,1)" le "3")
  or "%substr(&sysver,1,1)"="4"
  or "%substr(&sysver,1,1)"="5"
%then %do;DATETIME19.3%end;
%else %do;E8601DT26.6%end;

%mend mf_fmtdttm;


