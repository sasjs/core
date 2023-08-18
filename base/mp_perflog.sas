/**
  @file
  @brief Logs a message in a dataset every time it is invoked
  @details If the dataset does not exist, it is created.
  Usage:

      %mp_perflog(started)
      %mp_perflog()
      %mp_perflog(startanew,libds=work.newdataset)
      %mp_perflog(finished,libds=work.newdataset)
      %mp_perflog(finished)


  @param [in] label Provide label to go into the control dataset
  @param [in] libds= (work.mp_perflog) Provide a dataset in which to store
    performance stats.  Default name is <code>work.mp_perflog</code>;

  @version 9.2
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_perflog(label,libds=work.mp_perflog
)/*/STORE SOURCE*/;

  %if not (%mf_existds(&libds)) %then %do;
    data &libds;
      length sysjobid $10 label $256 dttm 8.;
      format dttm datetime19.3;
      call missing(of _all_);
      stop;
    run;
  %end;

  proc sql;
    insert into &libds
      set sysjobid="&sysjobid"
        ,label=symget('label')
        ,dttm=%sysfunc(datetime());
  quit;

%mend mp_perflog;