/**
  @file
  @brief Aborts if a SAS lock file is in place, or if one cannot be applied.
  @details Used in conjuction with the mp_lockanytable macro.
  More info here: https://sasensei.com/flash/24

  Usage:

      data work.test; a=1;run;
      %mp_lockfilecheck(work.test)

  @param [in] libds The libref.dataset for which to check the lock status

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mf_getattrc.sas

  <h4> Related Macros </h4>
  @li mp_lockanytable.sas

  @version 9.2
**/

%macro mp_lockfilecheck(
  libds
)/*/STORE SOURCE*/;

data _null_;
  if _n_=1 then putlog "&sysmacroname entry vars:";
  set sashelp.vmacro;
  where scope="&sysmacroname";
  put name '=' value;
run;

%mp_abort(iftrue= (&syscc>0)
  ,mac=checklock.sas
  ,msg=Aborting with syscc=&syscc on entry.
)
%mp_abort(iftrue= (&libds=0)
  ,mac=&sysmacroname
  ,msg=%str(libds not provided)
)

%local msg lib ds;
%let lib=%upcase(%scan(&libds,1,.));
%let ds=%upcase(%scan(&libds,2,.));

/* do not proceed if no observations can be processed */
%let msg=options obs = 0. syserrortext=%superq(syserrortext);
%mp_abort(iftrue= (%sysfunc(getoption(OBS))=0)
  ,mac=checklock.sas
  ,msg=%superq(msg)
)

data _null_;
  putlog "Checking engine & member type";
run;
%local engine memtype;
%let memtype=%mf_getattrc(&libds,MTYPE);
%let engine=%mf_getattrc(&libds,ENGINE);

%if &engine ne V9 and &engine ne BASE %then %do;
  data _null_;
    putlog "Lib &lib  is not assigned using BASE engine - uses &engine instead";
    putlog "SAS lock check will not be performed";
  run;
  %return;
%end;
%else %if &memtype ne DATA %then %do;
  %put NOTE: Cannot lock a VIEW!! Memtype=&memtype;
  %return;
%end;

data _null_;
  putlog "Engine = &engine, memtype=&memtype";
  putlog "Attempting lock statement";
run;

lock &libds;

%local abortme;
%let abortme=0;
%if &syscc>0 or &SYSLCKRC ne 0 %then %do;
  %let msg=Unable to apply lock on &libds (SYSLCKRC=&SYSLCKRC syscc=&syscc);
  %put %str(ERR)OR: &sysmacroname: &msg;
  %let abortme=1;
%end;

lock &libds clear;

%mp_abort(iftrue= (&abortme=1)
  ,mac=&sysmacroname
  ,msg=%superq(msg)
)

%mend mp_lockfilecheck;