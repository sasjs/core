/**
  @file
  @brief Capture session start / finish times and request details
  @details For details, see http://www.rawsas.com/2015/09/logging-of-stored-process-server.html.
    Requires a base table in the following structure (name can be changed):

    proc sql;
    create table &libds(
       request_dttm num not null format=datetime.
      ,status_cd char(4) not null
      ,_metaperson varchar(100) not null
      ,_program varchar(500)
      ,sysuserid varchar(50)
      ,sysjobid varchar(12)
      ,_sessionid varchar(50)
    );

    Called via STP init / term events (configurable in SMC) as follows:

    %mp_stprequests(status_cd=INIT, libds=YOURLIB.DATASET )


  @param status_cd= Use INIT for INIT and TERM for TERM events
  @param libds= Location of base table (library.dataset).  To minimise risk
    of table locks, we HIGHLY recommend using a database (NOT a SAS dataset).
    THE LIBRARY SHOULD BE ASSIGNED ALREADY - eg in autoexec or earlier in the
    init program proper.

  @version 9.2
  @author Allan Bowe
  @source https://github.com/macropeople/macrocore

**/

%macro mp_stprequests(status_cd= /* $4 eg INIT or TERM */
      ,libds=somelib.stp_requests /* base table location  */
)/*/STORE SOURCE*/;

  /* set nosyntaxcheck so the code runs regardless */
  %local etls_syntaxcheck;
  %let etls_syntaxcheck=%sysfunc(getoption(syntaxcheck));
  options nosyntaxcheck;

  data ;
    if 0 then set &libds;
    request_dttm=datetime();
    status_cd="&status_cd";
    _METAPERSON="&_metaperson";
    _PROGRAM="&_program";
    SYSUSERID="&sysuserid";
    SYSJOBID="&sysjobid";
  %if not %symexist(_SESSIONID) %then %do;
    /* session id is stored in the replay variable but needs to be extracted */
    _replay=symget('_replay');
    _replay=subpad(_replay,index(_replay,'_sessionid=')+11,length(_replay));
    index=index(_replay,'&')-1;
    if index=-1 then index=length(_replay);
    _replay=substr(_replay,1,index);
    _SESSIONID=_replay;
    drop _replay index;
  %end;
  %else %do;
    /* explicitly created sessions are automatically available */
    _SESSIONID=symget('_SESSIONID');
  %end;
    output;
    stop;
  run;

  proc append base=&libds data=&syslast nowarn;run;

  options &etls_syntaxcheck;
%mend;