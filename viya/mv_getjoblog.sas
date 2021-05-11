/**
  @file
  @brief Extract the log from a completed SAS Viya Job
  @details Extracts log from a Viya job and writes it out to a fileref.

  To query the job, you need the URI.  Sample code for achieving this
  is provided below.

  ## Example

      %* First, compile the macros;
      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

      %* Next, create a job (in this case, a web service);
      filename ft15f001 temp;
      parmcards4;
        data ;
          rand=ranuni(0)*1000;
          do x=1 to rand;
            y=rand*4;
            output;
          end;
        run;
        proc sort data=&syslast
          by descending y;
        run;
      ;;;;
      %mv_createwebservice(path=/Public/temp,name=demo)

      %* Execute it;
      %mv_jobexecute(path=/Public/temp
        ,name=demo
        ,outds=work.info
      )

      %* Wait for it to finish;
      data work.info;
        set work.info;
        where method='GET' and rel='state';
      run;
      %mv_jobwaitfor(ALL,inds=work.info,outds=work.jobstates)

      %* and grab the uri;
      data _null_;
        set work.jobstates;
        call symputx('uri',uri);
      run;

      %* Finally, fetch the log;
      %mv_getjoblog(uri=&uri,outref=mylog)

  This macro is used by the mv_jobwaitfor.sas macro, which is generally a more
  convenient way to wait for the job to finish before fetching the log.

  If the remote session calls `endsas` then it is not possible to get the log
  from the provided uri, and so the log from the parent session is fetched
  instead.  This happens for a 400 response, eg below:

      ErrorResponse[version=2,status=400,err=5113,id=,message=The session
      requested is currently in a failed or stopped state.,detail=[path:
      /compute/sessions/LONGURI-ses0006/jobs/LONGURI/log/content, traceId: 63
      51aa617d01fd2b],remediation=Correct the errors in the session request,
      and create a new session.,targetUri=<null>,errors=[],links=[]]

  @param [in] access_token_var= The global macro variable to contain the access
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
  @param [out] outref= The output fileref to which to APPEND the log (is always
  appended).


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_existfileref.sas
  @li ml_json.sas

**/

%macro mv_getjoblog(uri=0,outref=0
    ,contextName=SAS Job Execution compute context
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,mdebug=0
  );
%local dbg;
%if &mdebug=1 %then %do;
  %put &sysmacroname entry vars:;
  %put _local_;
%end;
%else %let dbg=*;

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
      !!" but is actually like:"!!uri,'l');
  end;
run;

%mp_abort(iftrue=(&errflg=1)
  ,mac=&sysmacroname
  ,msg=%str(&errmsg)
)

%mp_abort(iftrue=(&outref=0)
  ,mac=&sysmacroname
  ,msg=%str(Output fileref should be provided)
)

%if %mf_existfileref(&outref) ne 1 %then %do;
  filename &outref temp;
%end;

options noquotelenmax;
%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

/* prepare request*/
%local  fname1;
%let fname1=%mf_getuniquefileref();
proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri&uri";
  headers
  %if &grant_type=authorization_code %then %do;
          "Authorization"="Bearer &&&access_token_var"
  %end;
  ;
run;
%if &mdebug=1 %then %do;
  %put &sysmacroname: fetching log loc from &uri;
  data _null_;infile &fname1;input;putlog _infile_;run;
%end;
%if &SYS_PROCHTTP_STATUS_CODE ne 200 and &SYS_PROCHTTP_STATUS_CODE ne 201 %then
%do;
  data _null_;infile &fname1;input;putlog _infile_;run;
  %mp_abort(mac=&sysmacroname
    ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
%end;
%local  fname2 fname3 fpath1 fpath2 fpath3;
%let fname2=%mf_getuniquefileref();
%let fname3=%mf_getuniquefileref();
%let fpath1=%sysfunc(pathname(&fname1));
%let fpath2=%sysfunc(pathname(&fname2));
%let fpath3=%sysfunc(pathname(&fname3));

/* compile the lua JSON module */
%ml_json()
/* read using LUA - this allows the code to be of any length */
data _null_;
  file "&fpath3..lua";
  put '
    infile = io.open (sas.symget("fpath1"), "r")
    outfile = io.open (sas.symget("fpath2"), "w")
    io.input(infile)
    local resp=json.decode(io.read())
    local logloc=resp["logLocation"]
    outfile:write(logloc)
    io.close(infile)
    io.close(outfile)
  ';
run;
%inc "&fpath3..lua";
/* get log path*/
%let errflg=1;
%let errmsg=No entry in &fname2 fileref;
data _null_;
  infile &fname2;
  input;
  uri=cats(_infile_);
  if length(uri)<12 then do;
    call symputx('errflg',1);
    call symputx('errmsg',"URI is invalid (too short) - '&uri'",'l');
  end;
  else if (scan(uri,1,'/') ne 'compute' or scan(uri,2,'/') ne 'sessions')
    and (scan(uri,1,'/') ne 'files' or scan(uri,2,'/') ne 'files')
  then do;
    call symputx('errflg',1);
    call symputx('errmsg',
      "URI should be in format /compute/sessions/$$$$UUID$$$$/jobs/$$$$UUID$$$$"
      !!" or /files/files/$$$$UUID$$$$"
      !!" but is actually like:"!!uri,'l');
  end;
  else do;
    call symputx('errflg',0,'l');
    call symputx('logloc',uri,'l');
  end;
run;

%mp_abort(iftrue=(%str(&errflg)=1)
  ,mac=&sysmacroname
  ,msg=%str(&errmsg)
)

/* we have a log uri - now fetch the log */
%&dbg.put &sysmacroname: querying &base_uri&logloc/content;
proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri&logloc/content?limit=10000";
  headers
  %if &grant_type=authorization_code %then %do;
          "Authorization"="Bearer &&&access_token_var"
  %end;
  ;
run;

%if &mdebug=1 %then %do;
  %put &sysmacroname: fetching log content from &base_uri&logloc/content;
  data _null_;infile &fname1;input;putlog _infile_;run;
%end;

%if &SYS_PROCHTTP_STATUS_CODE=400 %then %do;
  /* fetch log from parent session */
  %let logloc=%substr(&logloc,1,%index(&logloc,%str(/jobs/))-1);
  %&dbg.put &sysmacroname: Now querying &base_uri&logloc/log/content;
  proc http method='GET' out=&fname1 &oauth_bearer
    url="&base_uri&logloc/log/content?limit=10000";
    headers
    %if &grant_type=authorization_code %then %do;
            "Authorization"="Bearer &&&access_token_var"
    %end;
    ;
  run;
  %if &mdebug=1 %then %do;
    %put &sysmacroname: fetching log content from &base_uri&logloc/log/content;
    data _null_;infile &fname1;input;putlog _infile_;run;
  %end;
%end;

%if &SYS_PROCHTTP_STATUS_CODE ne 200 and &SYS_PROCHTTP_STATUS_CODE ne 201
%then %do;
  %if &mdebug ne 1 %then %do; /* have already output above */
    data _null_;infile &fname1;input;putlog _infile_;run;
  %end;
  %mp_abort(mac=&sysmacroname
    ,msg=%str(logfetch: &SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
  )
%end;
data _null_;
  file "&fpath3..lua";
  put '
    infile = io.open (sas.symget("fpath1"), "r")
    outfile = io.open (sas.symget("fpath2"), "w")
    io.input(infile)
    local resp=json.decode(io.read())
    for i, v in pairs(resp["items"]) do
      outfile:write(v.line,"\n")
    end
    io.close(infile)
    io.close(outfile)
  ';
run;
%inc "&fpath3..lua";

/* write log out to the specified fileref */
data _null_;
  infile &fname2 end=last;
  file &outref mod;
  if _n_=1 then do;
    put "/** SASJS Viya Job Log Extract start: &uri **/";
  end;
  input;
  put _infile_;
  %if &mdebug=1 %then %do;
    putlog _infile_;
  %end;
  if last then do;
    put "/** SASJS Viya Job Log Extract end: &uri **/";
  end;
run;

%if &mdebug=0 %then %do;
  filename &fname1 clear;
  filename &fname2 clear;
  filename &fname3 clear;
%end;
%else %do;
  %put &sysmacroname exit vars:;
  %put _local_;
%end;
%mend mv_getjoblog;



