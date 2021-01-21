/**
  @file
  @brief Runs arbitrary code for a specified amount of time
  @details Executes a series of procs and data steps to enable performance
  testing of arbitrary jobs.

      %mp_testjob(
         duration=60*5
      )

  @param [in] duration= the time in seconds which the job should run for. Actual
  time may vary, as the check is done in between steps.  Default = 30 (seconds).

  <h4> SAS Macros </h4>
  @li mf_getuniquelibref.sas
  @li mf_getuniquename.sas
  @li mf_mkdir.sas

  @version 9.4
  @author Allan Bowe

**/

%macro mp_testjob(duration=30
)/*/STORE SOURCE*/;
%local lib dir ds1 ds2 ds3 start_tm i;

%let start_tm=%sysfunc(datetime());

/* create a temporary library in WORK */
%let lib=%mf_getuniquelibref();
%let dir=%mf_getuniquename();
%mf_mkdir(%sysfunc(pathname(work))/&dir)
libname &lib "%sysfunc(pathname(work))/&dir";

/* loop through until time expires */
%let ds1=%mf_getuniquename();
%let ds2=%mf_getuniquename();
%let ds3=%mf_getuniquename();
%do i=0 %to 1;

  /* create big dataset */
  data &lib..&ds1(compress=no );
    do x=1 to 1000000;
      randnum0=ranuni(0)*3;
      randnum1=ranuni(0)*2;
      bigchar=repeat('A',300);
      output;
    end;
  run;
  %if %sysevalf( (%sysfunc(datetime())-&start_tm)>&duration ) %then %goto gate;

  proc summary ;
    class randnum0 randnum1;
    output out=&lib..&ds2;
  run;
  %if %sysevalf( (%sysfunc(datetime())-&start_tm)>&duration ) %then %goto gate;

  /* add more data */
  proc sql;
  create table &lib..&ds3 as
    select *, ranuni(0)*10 as randnum2
  from &lib..&ds1
  order by randnum1;
  %if %sysevalf( (%sysfunc(datetime())-&start_tm)>&duration ) %then %goto gate;

  proc sort data=&lib..&ds3;
    by descending x;
  run;
  %if %sysevalf( (%sysfunc(datetime())-&start_tm)>&duration ) %then %goto gate;

  /* wait 5 seconds */
  data _null_;
    call sleep(5,1);
  run;
  %if %sysevalf( (%sysfunc(datetime())-&start_tm)>&duration ) %then %goto gate;

  %let i=0;

%end;

%gate:
%put time is up!;
proc datasets lib=&lib kill;
run;
quit;
libname &lib clear;


%mend;