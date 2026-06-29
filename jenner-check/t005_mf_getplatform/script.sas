/* mf_getplatform.sas (from sasjs/core base/) - detects the SAS platform
   (BASESAS / SASVIYA / SASMETA / SASJS). The related helper macros it can
   call on some switches (mf_mval, mf_trimstr) are bundled alongside so the
   definition is complete. */

%macro mf_mval(var);
  %if %symexist(&var) %then %do;
    %superq(&var)
  %end;
%mend mf_mval;

%macro mf_trimstr(basestr,trimstr);
%local baselen trimlen trimval;

%let baselen=%length(%superq(basestr));
%let trimlen=%length(%superq(trimstr));
%if &baselen < &trimlen or &baselen=0 %then %return;

%let trimval=%qsubstr(%superq(basestr)
  ,%length(%superq(basestr))-&trimlen+1
  ,&trimlen);

%if %superq(basestr)=%superq(trimstr) %then %do;
  %return;
%end;
%else %if %superq(trimval)=%superq(trimstr) %then %do;
  %qsubstr(%superq(basestr),1,%length(%superq(basestr))-&trimlen)
%end;
%else %do;
  &basestr
%end;

%mend mf_trimstr;

%macro mf_getplatform(switch
);
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

/* Documented usage: default call returns the platform name */
%let platform=%mf_getplatform();

data work.platform_check;
  length detected_platform $12;
  detected_platform = "&platform";
  output;
run;

proc print data=work.platform_check noobs; run;
%put NOTE: mf_getplatform() detected &platform;
