/**
  @file
  @brief Extract the result from a completed SAS Viya Job
  @details Extracts result from a Viya job and writes it out to a fileref
  and/or a JSON-engine library.

  To query the job, you need the URI.  Sample code for achieving this
  is provided below.

  ## Example

  First, compile the macros:

      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

  Next, create a job (in this case, a web service):

      filename ft15f001 temp;
      parmcards4;
        data test;
          rand=ranuni(0)*1000;
          do x=1 to rand;
            y=rand*4;
            output;
          end;
        run;
        proc sort data=&syslast
          by descending y;
        run;
        %webout(OPEN)
        %webout(OBJ, test)
        %webout(CLOSE)
      ;;;;
      %mv_createwebservice(path=/Public/temp,name=demo)

  Execute it:

      %mv_jobexecute(path=/Public/temp
        ,name=demo
        ,outds=work.info
      )

  Wait for it to finish, and grab the uri:

      data _null_;
        set work.info;
        if method='GET' and rel='self';
        call symputx('uri',uri);
      run;

  Finally, fetch the result (In this case, WEBOUT):

      %mv_getjobresult(uri=&uri,result=WEBOUT_JSON,outref=myweb,outlib=myweblib)


  @param [in] access_token_var= The global macro variable containing the access
    token
  @param [in] mdebug= set to 1 to enable DEBUG messages
  @param [in] grant_type= valid values:
    @li password
    @li authorization_code
    @li detect - will check if access_token exists, if not will use sas_services
        if a SASStudioV session else authorization_code.  Default option.
    @li sas_services - will use oauth_bearer=sas_services.
  @param [in] uri= The uri of the running job for which to fetch the status,
    in the format `/jobExecution/jobs/$UUID` (unquoted).

  @param [out] result= (WEBOUT_JSON) The result type to capture.  Resolves
  to "_[column name]" from the results table when parsed with the JSON libname
  engine.  Example values:
    @li WEBOUT_JSON
    @li WEBOUT_TXT
  A job whose webout is a binary file registers it under its own name -
  `_webout.pdf`, `_webout.xlsx` and so on - and a dotted key cannot be
  requested through this parameter.  When the requested member is absent the
  macro falls back to the first `_WEBOUT*` member of the results that holds a
  files uri, so a binary webout is returned without the caller naming it.

  @param [out] outref= (0) The output fileref to which to write the results
  @param [out] outlib= (0) The output library to which to assign the results
    (assumes the data is in JSON format)


  @version VIYA V.03.05
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mp_binarycopy.sas
  @li mp_replace.sas
  @li mf_getplatform.sas
  @li mf_existfileref.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas

**/

%macro mv_getjobresult(uri=0
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,mdebug=0
    ,result=WEBOUT_JSON
    ,outref=0
    ,outlib=0
  );
%if &mdebug=1 %then %do;
  %put &sysmacroname entry vars:;
  %put _local_;
%end;

%local oauth_bearer;
%if &grant_type=detect %then %do;
  %if %symexist(&access_token_var) %then %let grant_type=authorization_code;
  %else %let grant_type=sas_services;
%end;
%if &grant_type=sas_services %then %do;
    %let oauth_bearer=oauth_bearer=sas_services;
    %let &access_token_var=;
%end;

%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password
    and &grant_type ne sas_services
  )
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)


/* validation in datastep for better character safety */
%local errmsg errflg;
data _null_;
  uri=symget('uri');
  if length(uri)<12 then do;
    call symputx('errflg',1);
    call symputx('errmsg',"URI is invalid (too short) - '&uri'",'l');
  end;
  if scan(uri,-1)='state' or scan(uri,1) ne 'jobExecution' then do;
    call symputx('errflg',1);
    call symputx('errmsg',
      "URI should be in format /jobExecution/jobs/$$$$UUID$$$$"
      !!" but is actually like: &uri",'l');
  end;
run;

%mp_abort(iftrue=(&errflg=1)
  ,mac=&sysmacroname
  ,msg=%str(&errmsg)
)

%if &outref ne 0 and %mf_existfileref(&outref) ne 1 %then %do;
  filename &outref temp;
%end;

options noquotelenmax;
%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

/* fetch job info */
%local fname1;
%let fname1=%mf_getuniquefileref();
proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri&uri";
  headers "Accept"="application/json"
  %if &grant_type=authorization_code %then %do;
          "Authorization"="Bearer &&&access_token_var"
  %end;
  ;
run;
%if &SYS_PROCHTTP_STATUS_CODE ne 200 and &SYS_PROCHTTP_STATUS_CODE ne 201 %then
%do;
  data _null_;infile &fname1;input;putlog _infile_;run;
  %mp_abort(mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
%end;
%if &mdebug=1 %then %do;
  data _null_;
    infile &fname1 lrecl=32767;
    input;
    putlog _infile_;
  run;
%end;

/* extract results link */
%local lib1 resuri resname resfall want;
%let resfall=0;
%let want=%upcase(_&result);
%let lib1=%mf_getuniquelibref();
libname &lib1 JSON fileref=&fname1;
/* The member is located by name rather than referenced by name: a results
  * table with no such column cannot be addressed in a data step at all.  A
  * binary webout registers itself as _webout.pdf / .xlsx / .zip, which
  * result= cannot express, so when the requested member is missing the first
  * _WEBOUT* column holding a files uri is taken instead - a job that
  * registered more than one binary member cannot steer this, so only one
  * binary member per job is supported. */
data _null_;
  set &lib1..results;
  array _chars{*} _character_;
  length _name $32 _val $512;
  do _i=1 to dim(_chars);
    _name=vname(_chars{_i});
    if upcase(_name)=symget('want') then do;
      _val=_chars{_i};
      leave;
    end;
  end;
  if _val eq '' then do _i=1 to dim(_chars);
    _name=vname(_chars{_i});
    if _chars{_i}=:'/files/' and upcase(_name)=:'_WEBOUT' then do;
      _val=_chars{_i};
      call symputx('resfall',1,'l');
      leave;
    end;
  end;
  if _val ne '' then do;
    call symputx('resuri',_val,'l');
    call symputx('resname',_name,'l');
  end;
  %if &mdebug=1 %then %do;
    putlog "&sysmacroname results: " (_all_)(=);
  %end;
run;
%if &mdebug=1 and &resfall=1 %then %do;
  %put &sysmacroname: _&result was not registered, using &resname;
%end;
%if "%superq(resuri)" eq "" or "%superq(resuri)" eq "." %then %do;
  /* The requested result was not registered - typical for a canceled
    * job whose session ended before the result file was created (eg a
    * job aborted by design, or a job that failed on session creation).
    * Aborting here would terminate the calling program, so write an
    * empty payload and return - the caller can check the job state
    * (from the outds of the wait macro) and decide what to do. */
  %put &sysmacroname: _&result not found in job results -;
  %put &sysmacroname: use mv_getjoblog to fetch the job log instead;
  %if &outref ne 0 %then %do;
    data _null_;
      file &outref;
      put "&sysmacroname: no &_result result available for job &uri";
    run;
  %end;
  %if &outlib ne 0 %then %do;
    %local fname3;
    %let fname3=%mf_getuniquefileref();
    data _null_;
      file &fname3;
      put '{}';
    run;
    libname &outlib JSON fileref=&fname3;
  %end;
  %if &mdebug=0 %then %do;
    filename &fname1 clear;
    libname &lib1 clear;
  %end;
  %return;
%end;

/* extract results */
%local fname2;
%let fname2=%mf_getuniquefileref();
proc http method='GET' out=&fname2 &oauth_bearer
  url="&base_uri&resuri/content?limit=10000";
  headers "Accept"="application/json"
  %if &grant_type=authorization_code %then %do;
          "Authorization"="Bearer &&&access_token_var"
  %end;
  ;
run;
%if &mdebug=1 %then %do;
  /* send one char at a time as the json can be very wide */
  data _null_;
    infile &fname2 recfm=n;
    input char $char1. ;
    putlog char $char1. @;
  run;
%end;

%if &outref ne 0 %then %do;
  filename &outref temp;
  %mp_binarycopy(inref=&fname2,outref=&outref)
%end;
%if &outlib ne 0 %then %do;
  /* A service run through Viya job execution wraps its response in the
    * transport envelope (>>weboutBEGIN<< ... >>weboutEND<<) - that is what the
    * client frames the response with.  The text path in mx_execute strips it,
    * but the JSON engine has no such step and rejects the marker on line one,
    * which is why an aborted child's result looked unparsable when the abort
    * object inside it was perfectly good.
    *
    * Detection is the strip: mp_replace copies a byte at a time, so the markers
    * come out wherever they sit, and a smaller output than input is the answer
    * to "was there an envelope".  Probing the first record instead would miss a
    * marker that is not in it, which is the failure this exists to remove,
    * and a result without an envelope keeps the direct libname. */
  %local path2 path3 begvar endvar nil fref3 fref4 fid size2 size4;
  %let fref3=%mf_getuniquefileref();
  %let fref4=%mf_getuniquefileref();
  %let path2=%sysfunc(pathname(&fname2));
  %let path3=%sysfunc(pathname(&fref3));
  %let begvar=%str(>>weboutBEGIN<<);
  %let endvar=%str(>>weboutEND<<);
  %let nil=;
  %mp_replace(infile="&path2",findvar=begvar,replacevar=nil
    ,outfile="&path3")
  %mp_replace(infile="&path3",findvar=endvar,replacevar=nil
    ,outfile="%sysfunc(pathname(&fref4))")
  /* a copy that could not be written is not an outcome: say so, rather than
    * handing the engine an empty file and failing at the libname instead */
  %if %sysfunc(fexist(&fref4)) ne 1 %then %do;
    %mp_abort(mac=&sysmacroname
      ,msg=%str(Unable to strip the result envelope for &uri)
    )
  %end;
  %let fid=%sysfunc(fopen(&fname2));
  %let size2=%sysfunc(finfo(&fid,File Size (bytes)));
  %let fid=%sysfunc(fclose(&fid));
  %let fid=%sysfunc(fopen(&fref4));
  %let size4=%sysfunc(finfo(&fid,File Size (bytes)));
  %let fid=%sysfunc(fclose(&fid));
  %if &size4 < &size2 %then %do;
    /* nothing but envelope is a real outcome - a service that aborted before
      * writing anything - and becomes the empty object the not-found branch
      * hands back, rather than an empty file the engine cannot open */
    %if &size4=0 %then %do;
      data _null_;
        file &fref4;
        put '{}';
      run;
    %end;
    libname &outlib JSON fileref=&fref4;
  %end;
  %else %do;
    libname &outlib JSON fileref=&fname2;
  %end;
  filename &fref3 clear;
  filename &fref4 clear;
%end;

%if &mdebug=0 %then %do;
  filename &fname1 clear;
  filename &fname2 clear;
  libname &lib1 clear;
%end;
%else %do;
  %put &sysmacroname exit vars:;
  %put _local_;
%end;

%mend mv_getjobresult;
