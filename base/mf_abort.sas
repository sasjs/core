/**
  @file
  @brief abort gracefully according to context
  @details Do not use directly!  See bottom of explanation for details.

   Configures an abort mechanism according to site specific policies or the
    particulars of an environment.  For instance, can stream custom
    results back to the client in an STP Web App context, or completely stop
    in the case of a batch run.

  For the sharp eyed readers - this is no longer a macro function!! It became
  a macro procedure during a project and now it's kinda stuck that way until
  that project is updated (if it's ever updated).  In the meantime we created
  `mp_abort` which is just a wrapper for this one, and so we recomend you use
  that for forwards compatibility reasons.

  @param mac= to contain the name of the calling macro
  @param type= deprecated.  Not used.
  @param msg= message to be returned
  @param iftrue= supply a condition under which the macro should be executed.

  @version 9.2
  @author Allan Bowe
**/  /** @cond */

%macro mf_abort(mac=mf_abort.sas, type=, msg=, iftrue=%str(1=1)
)/*/STORE SOURCE*/;

  %if not(%eval(%unquote(&iftrue))) %then %return;

  %put NOTE: ///  mf_abort macro executing //;
  %if %length(&mac)>0 %then %put NOTE- called by &mac;
  %put NOTE - &msg;

  /* Stored Process Server web app context */
  %if %symexist(_metaperson) or "&SYSPROCESSNAME"="Compute Server" %then %do;
    options obs=max replace nosyntaxcheck mprint;
    /* extract log err / warn, if exist */
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
        if (_infile_=:"%str(WARN)ING" or _infile_=:"%str(ERR)OR") and logonce=0 then do;
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
          if _n_ ge &logline-5 and stoploop=0 then do until (i>12);
            call symputx('logmsg',catx('\n',symget('logmsg'),_infile_));
            input;
            i+1;
            stoploop=1;
          end;
          if stoploop=1 then stop;
        run;
      %end;
    %end;

    /* send response in SASjs JSON format */
    data _null_;
      file _webout mod lrecl=32000;
      length msg $32767;
      sasdatetime=datetime();
      msg=cats(symget('msg'),'\n\nLog Extract:\n',symget('logmsg'));
      /* escape the quotes */
      msg=tranwrd(msg,'"','\"');
      /* ditch the CRLFs as chrome complains */
      msg=compress(msg,,'kw');
      /* quote without quoting the quotes (which are escaped instead) */
      msg=cats('"',msg,'"');
      if symexist('_debug') then debug=symget('_debug');
      if debug ge 131 then put '>>weboutBEGIN<<';
      put '{"START_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '"';
      put ',"sasjsAbort" : [{';
      put ' "MSG":' msg ;
      put ' ,"MAC": "' "&mac" '"}]';
      put ",""SYSUSERID"" : ""&sysuserid"" ";
      if symexist('_metauser') then do;
        _METAUSER=quote(trim(symget('_METAUSER')));
        put ",""_METAUSER"": " _METAUSER;
        _METAPERSON=quote(trim(symget('_METAPERSON')));
        put ',"_METAPERSON": ' _METAPERSON;
      end;
      _PROGRAM=quote(trim(resolve(symget('_PROGRAM'))));
      put ',"_PROGRAM" : ' _PROGRAM ;
      put ",""SYSCC"" : ""&syscc"" ";
      put ",""SYSERRORTEXT"" : ""&syserrortext"" ";
      put ",""SYSJOBID"" : ""&sysjobid"" ";
      put ",""SYSWARNINGTEXT"" : ""&syswarningtext"" ";
      put ',"END_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '" ';
      put "}" @;
      %if &_debug ge 131 %then %do;
        put '>>weboutEND<<';
      %end;
    run;
    %let syscc=0;
    %if %symexist(SYS_JES_JOB_URI) %then %do;
      /* refer web service output to file service in one hit */
      filename _webout filesrvc parenturi="&SYS_JES_JOB_URI" name="_webout.json";
      %let rc=%sysfunc(fcopy(_web,_webout));
    %end;
    %else %do;
      data _null_;
        if symexist('sysprocessmode')
         then if symget("sysprocessmode")="SAS Stored Process Server"
          then rc=stpsrvset('program error', 0);
      run;
    %end;
    /**
     * endsas is reliable but kills some deployments.
     * Abort variants are ungraceful (non zero return code)
     * This approach lets SAS run silently until the end :-)
     */
    %put _all_;
    filename skip temp;
    data _null_;
      file skip;
      put '%macro skip(); %macro skippy();';
    run;
    %inc skip;
  %end;
  %else %do;
    %put _all_;
    %abort cancel;
  %end;
%mend;

/** @endcond */