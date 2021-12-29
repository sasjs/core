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
    and set SYSCC=0.  We take a unique "soft abort" approach - we open a macro
    but don't close it!  This works everywhere EXCEPT inside a \%include inside
    a macro.  For that, we recommend you use mp_include.sas to perform the
    include, and then call \%mp_abort(mode=INCLUDE) from the source program (ie,
    OUTSIDE of the top-parent macro).


  @param mac= to contain the name of the calling macro
  @param msg= message to be returned
  @param iftrue= supply a condition under which the macro should be executed.
  @param errds= (work.mp_abort_errds) There is no clean way to end a process
    within a %include called within a macro.  Furthermore, there is no way to
    test if a macro is called within a %include.  To handle this particular
    scenario, the %include should be switched for the mp_include.sas macro.
    This provides an indicator that we are running a macro within a \%include
    (`_SYSINCLUDEFILEDEVICE`) and allows us to provide a dataset with the abort
    values (msg, mac).
    We can then run an abort cancel FILE to stop the include running, and pass
    the dataset back to the calling program to run a regular \%mp_abort().
    The dataset will contain the following fields:
    @li iftrue (1=1)
    @li msg (the message)
    @li mac (the mac param)

  @param mode= (REGULAR) If mode=INCLUDE then the &errds dataset is checked for
    an abort status.
    Valid values:
    @li REGULAR (default)
    @li INCLUDE

  <h4> Related Macros </h4>
  @li mp_include.sas

  @version 9.4
  @author Allan Bowe
  @cond
**/

%macro mp_abort(mac=mp_abort.sas, type=, msg=, iftrue=%str(1=1)
  , errds=work.mp_abort_errds
  , mode=REGULAR
)/*/STORE SOURCE*/;

  %global sysprocessmode sysprocessname;

  %if not(%eval(%unquote(&iftrue))) %then %return;

  %put NOTE: ///  mp_abort macro executing //;
  %if %length(&mac)>0 %then %put NOTE- called by &mac;
  %put NOTE - &msg;

  %if %symexist(_SYSINCLUDEFILEDEVICE) %then %do;
    %if "*&_SYSINCLUDEFILEDEVICE*" ne "**" %then %do;
      data &errds;
        iftrue='1=1';
        length mac $100 msg $5000;
        mac=symget('mac');
        msg=symget('msg');
      run;
      data _null_;
        abort cancel FILE;
      run;
      %return;
    %end;
  %end;

  /* Stored Process Server web app context */
  %if %symexist(_metaperson)
    or "&SYSPROCESSNAME "="Compute Server "
    or &mode=INCLUDE
  %then %do;
    options obs=max replace nosyntaxcheck mprint;
    %if &mode=INCLUDE %then %do;
      %if %sysfunc(exist(&errds))=1 %then %do;
        data _null_;
          set &errds;
          call symputx('iftrue',iftrue,'l');
          call symputx('mac',mac,'l');
          call symputx('msg',msg,'l');
          putlog (_all_)(=);
        run;
        %if (&iftrue)=0 %then %return;
      %end;
      %else %do;
        %put &sysmacroname: No include errors found;
        %return;
      %end;
    %end;

    /* extract log errs / warns, if exist */
    %local logloc logline;
    %global logmsg; /* capture global messages */
    %if %symexist(SYSPRINTTOLOG) %then %let logloc=&SYSPRINTTOLOG;
    %else %let logloc=%qsysfunc(getoption(LOG));
    proc printto log=log;run;
    %let logline=0;
    %if %length(&logloc)>0 %then %do;
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
      length msg $32767 ;
      sasdatetime=datetime();
      msg=symget('msg');
    %if &logline>0 %then %do;
      msg=cats(msg,'\n\nLog Extract:\n',symget('logmsg'));
    %end;
      /* escape the quotes */
      msg=tranwrd(msg,'"','\"');
      /* ditch the CRLFs as chrome complains */
      msg=compress(msg,,'kw');
      /* quote without quoting the quotes (which are escaped instead) */
      msg=cats('"',msg,'"');
      if symexist('_debug') then debug=quote(trim(symget('_debug')));
      else debug='""';
      put '>>weboutBEGIN<<';
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
      syserrortext=quote(trim(symget('syserrortext')));
      put ",""SYSERRORTEXT"" : " syserrortext;
      put ",""SYSHOSTNAME"" : ""&syshostname"" ";
      put ",""SYSJOBID"" : ""&sysjobid"" ";
      put ",""SYSSCPL"" : ""&sysscpl"" ";
      put ",""SYSSITE"" : ""&syssite"" ";
      sysvlong=quote(trim(symget('sysvlong')));
      put ',"SYSVLONG" : ' sysvlong;
      syswarningtext=quote(trim(symget('syswarningtext')));
      put ",""SYSWARNINGTEXT"" : " syswarningtext;
      put ',"END_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '" ';
      put "}" @;
      put '>>weboutEND<<';
    run;

    %put _all_;

    %if "&sysprocessmode " = "SAS Stored Process Server " %then %do;
      data _null_;
        putlog 'stpsrvset program err and syscc';
        rc=stpsrvset('program error', 0);
        call symputx("syscc",0,"g");
      run;
      /**
        * endsas kills 9.4m3 deployments by orphaning multibridges.
        * Abort variants are ungraceful (non zero return code)
        * This approach lets SAS run silently until the end :-)
        * Caution - fails when called within a %include within a macro
        * Use mp_include() to handle this.
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
        call symputx('syscc',0);
        abort cancel nolist;
      run;
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