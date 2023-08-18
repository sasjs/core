/**
  @file
  @brief Wait until a file arrives before continuing execution
  @details Loops with a `sleep()` command until a file arrives or the max wait
  period expires.

  Example: Wait 3 minutes OR for /tmp/flag.txt to appear

    %mp_wait4file(/tmp/flag.txt , maxwait=60*3)

  @param [in] file The file to wait for.  Must be provided.
  @param [in] maxwait= (0) Number of seconds to wait.  If set to zero, will
    loop indefinitely (to a maximum of 46 days, per SAS [documentation](
    https://support.sas.com/documentation/cdl/en/lrdict/64316/HTML/default/viewer.htm#a001418809.htm
    )).  Otherwise, execution will proceed upon sleep expiry.
  @param [in] interval= (1) The wait period between sleeps, in seconds


**/

%macro mp_wait4file(file, maxwait=0, interval=1);

%if %str(&file)=%str() %then %do;
  %put %str(ERR)OR: file not provided;
%end;

data _null_;
  maxwait=&maxwait;
  if maxwait=0 then maxwait=60*60*24*46;
  do until (fileexist("&file") or slept>maxwait );
    slept=sum(slept,sleep(&interval,1));
  end;
run;

%mend mp_wait4file;