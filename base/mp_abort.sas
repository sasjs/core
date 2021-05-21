/**
  @file
  @brief abort gracefully according to context
  @details Configures an abort mechanism according to site specific policies or
    the particulars of an environment.  For instance, can stream custom
    results back to the client in an STP Web App context, or completely stop
    in the case of a batch run.  For STP sessions

  The method used varies according to the context.  Important points:

  @li should not use endsas or abort cancel in 9.4m3 environments as this can
    cause hung multibridge sessions and result in a frozen STP server
  @li should not use endsas in viya 3.5 as this destroys the session and cannot
    fetch results (although both mv_getjoblog.sas and the @sasjs/adapter will
    recognise this and fetch the log of the parent session instead)
  @li STP environments must finish cleanly to avoid the log being sent to
    _webout.  To assist with this, we also run stpsrvset('program error', 0)
    and set SYSCC=0.  For 9.4m3 we take a unique approach - we open a macro
    but don't close it!  This provides a graceful abort, EXCEPT when called
    called within a %include within a macro (and that macro contains additional
    logic).  See mp_abort.test.nofix.sas for the example case.
    If you know of another way to gracefully abort a 9.4m3 STP session, we'd
    love to hear about it!


  @param mac= to contain the name of the calling macro
  @param msg= message to be returned
  @param iftrue= supply a condition under which the macro should be executed.

  @version 9.4M3
  @author Allan Bowe
  @cond
**/

%macro mp_abort(mac=mp_abort.sas, type=, msg=, iftrue=%str(1=1)
)/*/STORE SOURCE*/;

  %global sysprocessmode sysprocessname;

  %if not(%eval(%unquote(&iftrue))) %then %return;

  %put NOTE: ///  mp_abort macro executing //;
  %if %length(&mac)>0 %then %put NOTE- called by &mac;
  %put NOTE - &msg;

  /* Stored Process Server web app context */
  %if %symexist(_metaperson) or "&SYSPROCESSNAME "="Compute Server " %then %do;
    options obs=max replace nosyntaxcheck mprint;
    /* extract log errs / warns, if exist */
    %local logloc logline;
    %global logmsg; /* capture global messages */
    %if %symexist(SYSPRINTTOLOG) %then %let logloc=&SYSPRINTTOLOG;
    %else %let logloc=%qsysfunc(getoption(LOG));
    proc printto log=log;run;
    %if %length(&logloc)>0 %then %do;
      %let logline=0;
      data _null_;
        infile &logloc lrecl=5000;
        input; putlog _infile_;
        i=1;
        retain logonce 0;
        if (
            _infile_=:"%str(WARN)ING" or _infile_=:"%str(ERR)OR"
          ) and logonce=0 then
        do;
          call symputx('logline',_n_);
          logonce+1;
        end;
      run;
      /* capture log including lines BEFORE the err */
      %if &logline>0 %then %do;
        data _null_;
          infile &logloc lrecl=5000;
          input;
          i=1;
          stoploop=0;
          if _n_ ge &logline-15 and stoploop=0 then do until (i>22);
            call symputx('logmsg',catx('\n',symget('logmsg'),_infile_));
            input;
            i+1;
            stoploop=1;
          end;
          if stoploop=1 then stop;
        run;
      %end;
    %end;

    %if %symexist(SYS_JES_JOB_URI) %then %do;
      /* setup webout */
      OPTIONS NOBOMFILE;
      %if "X&SYS_JES_JOB_URI.X"="XX" %then %do;
          filename _webout temp lrecl=999999 mod;
      %end;
      %else %do;
        filename _webout filesrvc parenturi="&SYS_JES_JOB_URI"
          name="_webout.json" lrecl=999999 mod;
      %end;
    %end;

    /* send response in SASjs JSON format */
    data _null_;
      file _webout mod lrecl=32000 encoding='utf-8';
      length msg $32767 debug $8;
      sasdatetime=datetime();
      msg=cats(symget('msg'),'\n\nLog Extract:\n',symget('logmsg'));
      /* escape the quotes */
      msg=tranwrd(msg,'"','\"');
      /* ditch the CRLFs as chrome complains */
      msg=compress(msg,,'kw');
      /* quote without quoting the quotes (which are escaped instead) */
      msg=cats('"',msg,'"');
      if symexist('_debug') then debug=quote(trim(symget('_debug')));
      else debug='""';
      if debug ge '"131"' then put '>>weboutBEGIN<<';
      put '{"START_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '"';
      put ',"sasjsAbort" : [{';
      put ' "MSG":' msg ;
      put ' ,"MAC": "' "&mac" '"}]';
      put ",""SYSUSERID"" : ""&sysuserid"" ";
      put ',"_DEBUG":' debug ;
      if symexist('_metauser') then do;
        _METAUSER=quote(trim(symget('_METAUSER')));
        put ",""_METAUSER"": " _METAUSER;
        _METAPERSON=quote(trim(symget('_METAPERSON')));
        put ',"_METAPERSON": ' _METAPERSON;
      end;
      if symexist('SYS_JES_JOB_URI') then do;
        SYS_JES_JOB_URI=quote(trim(symget('SYS_JES_JOB_URI')));
        put ',"SYS_JES_JOB_URI": ' SYS_JES_JOB_URI;
      end;
      _PROGRAM=quote(trim(resolve(symget('_PROGRAM'))));
      put ',"_PROGRAM" : ' _PROGRAM ;
      put ",""SYSCC"" : ""&syscc"" ";
      put ",""SYSERRORTEXT"" : ""&syserrortext"" ";
      put ",""SYSJOBID"" : ""&sysjobid"" ";
      sysvlong=quote(trim(symget('sysvlong')));
      put ',"SYSVLONG" : ' sysvlong;
      put ",""SYSWARNINGTEXT"" : ""&syswarningtext"" ";
      put ',"END_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '" ';
      put "}" @;
      if debug ge '"131"' then put '>>weboutEND<<';
    run;

    %put _all_;

    %if "&sysprocessmode " = "SAS Stored Process Server " %then %do;
      data _null_;
        putlog 'stpsrvset program error and syscc';
        rc=stpsrvset('program error', 0);
        call symputx("syscc",0,"g");
      run;
      %if "%substr(&sysvlong.xxxxxxxxx,1,9)" ne "9.04.01M3" %then %do;
        %put NOTE: Ending SAS session due to:;
        %put NOTE- &msg;
        endsas;
      %end;
    %end;
    %else %if "&sysprocessmode " = "SAS Compute Server " %then %do;
      /* endsas kills the session making it harder to fetch results */
      data _null_;
        syswarningtext=symget('syswarningtext');
        syserrortext=symget('syserrortext');
        abort_msg=symget('msg');
        syscc=symget('syscc');
        sysuserid=symget('sysuserid');
        iftrue=symget('iftrue');
        put (_all_)(/=);
        abort cancel nolist;
      run;
    %end;
    %else %if "%substr(&sysvlong.xxxxxxxxx,1,9)" = "9.04.01M3" %then %do;
      /**
        * endsas kills 9.4m3 deployments by orphaning multibridges.
        * Abort variants are ungraceful (non zero return code)
        * This approach lets SAS run silently until the end :-)
        * Caution - fails when called within a %include within a macro
        * See tests/mp_abort.test.1 for an example case.
        */
      filename skip temp;
      data _null_;
        file skip;
        put '%macro skip();';
        comment '%mend skip; -> fix lint ';
        put '%macro skippy();';
        comment '%mend skippy; -> fix lint ';
      run;
      %inc skip;
    %end;
    %else %do;
      %abort cancel;
    %end;
  %end;
  %else %do;
    %put _all_;
    %abort cancel;
  %end;
%mend mp_abort;

/** @endcond */