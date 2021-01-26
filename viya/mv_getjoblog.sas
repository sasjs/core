/**
  @file
  @brief Extract the log from a completed SAS Viya Job
  @details Extracts log from a Viya job and writes it out to a fileref

  To query the job, you need the URI.  Sample code for achieving this
  is provided below.

  ## Example

  First, compile the macros:

      filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

  Next, create a job (in this case, a web service):

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

  Finally, fetch the log:

      %mv_getjoblog(uri=&uri,outref=mylog)

  This macro is used by the mv_jobwaitfor.sas macro, which is generally a more
  convenient way to wait for the job to finish before fetching the log.


  @param [in] access_token_var= The global macro variable to contain the access token
  @param [in] mdebug= set to 1 to enable DEBUG messages
  @param [in] grant_type= valid values:
    @li password
    @li authorization_code
    @li detect - will check if access_token exists, if not will use sas_services if
        a SASStudioV session else authorization_code.  Default option.
    @li sas_services - will use oauth_bearer=sas_services.
  @param [in] uri= The uri of the running job for which to fetch the status,
    in the format `/jobExecution/jobs/$UUID/state` (unquoted).
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
%local oauth_bearer;
%if &grant_type=detect %then %do;
  %if %symexist(&access_token_var) %then %let grant_type=authorization_code;
  %else %let grant_type=sas_services;
%end;
%if &grant_type=sas_services %then %do;
    %let oauth_bearer=oauth_bearer=sas_services;
    %let &access_token_var=;
%end;
%put &sysmacroname: grant_type=&grant_type;
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
  uri=_infile_;
  if length(uri)<12 then do;
    call symputx('errflg',1);
    call symputx('errmsg',"URI is invalid (too short) - '&uri'",'l');
  end;
  if scan(uri,1) ne 'files' or scan(uri,2) ne 'files' then do;
    call symputx('errflg',1);
    call symputx('errmsg',
      "URI should be in format /files/files/$$$$UUID$$$$"
      !!" but is actually like: &uri",'l');
  end;
  call symputx('errflg',0,'l');
  call symputx('logloc',uri,'l');
run;

%mp_abort(iftrue=(&errflg=1)
  ,mac=&sysmacroname
  ,msg=%str(&errmsg)
)

/* we have a log uri - now fetch the log */
proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri&logloc/content";
  headers
  %if &grant_type=authorization_code %then %do;
          "Authorization"="Bearer &&&access_token_var"
  %end;
  ;
run;
%if &SYS_PROCHTTP_STATUS_CODE ne 200 and &SYS_PROCHTTP_STATUS_CODE ne 201 %then
%do;
  data _null_;infile &fname1;input;putlog _infile_;run;
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
  %if &mdebug=0 %then %do;
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
  %put _local_;
%end;
%mend;



