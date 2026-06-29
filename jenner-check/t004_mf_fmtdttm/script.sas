/* mf_fmtdttm.sas (from sasjs/core base/) - returns the appropriate datetime
   format name for the running SAS version, so datetimes can be written
   consistently across SAS releases. */

%macro mf_fmtdttm(
);

%if "&sysver"="9.2" or "&sysver"="9.3"
  or ("&sysver"="9.4" and "%substr(&SYSVLONG,9,1)" le "3")
  or "%substr(&sysver,1,1)"="4"
  or "%substr(&sysver,1,1)"="5"
%then %do;DATETIME19.3%end;
%else %do;E8601DT26.6%end;

%mend mf_fmtdttm;

/* Documented usage: capture the format the macro selects for this session */
%let dttmfmt=%mf_fmtdttm();

data work.fmtdttm_check;
  length chosen_format $20 note $60;
  chosen_format = "&dttmfmt";
  /* the macro returns one of two valid datetime formats depending on version */
  if chosen_format in ('DATETIME19.3','E8601DT26.6')
    then note='valid datetime format returned';
    else note='UNEXPECTED format';
  output;
run;

proc print data=work.fmtdttm_check noobs; run;
%put NOTE: mf_fmtdttm() selected format &dttmfmt;
