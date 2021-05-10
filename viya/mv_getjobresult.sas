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

  @param [out] outref= (0) The output fileref to which to write the results
  @param [out] outlib= (0) The output library to which to assign the results
    (assumes the data is in JSON format)


  @version VIYA V.03.05
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mp_binarycopy.sas
  @li mf_getplatform.sas
  @li mf_existfileref.sas

**/

%macro mv_getjobresult(uri=0
    ,contextName=SAS Job Execution compute context
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,mdebug=0
    ,result=WEBOUT_JSON
    ,outref=0
    ,outlib=0
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
%local lib1 resuri;
%let lib1=%mf_getuniquelibref();
libname &lib1 JSON fileref=&fname1;
data _null_;
  set &lib1..results;
  call symputx('resuri',_&result,'l');
  &dbg putlog "&sysmacroname results: " (_all_)(=);
run;
%mp_abort(iftrue=("&resuri"=".")
  ,mac=&sysmacroname
  ,msg=%str(Variable _&result did not exist in the response json)
)

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
  data _null_;
    infile &fname2 lrecl=32767;
    input;
    putlog _infile_;
  run;
%end;

%if &outref ne 0 %then %do;
  filename &outref temp;
  %mp_binarycopy(inref=&fname2,outref=&outref)
%end;
%if &outlib ne 0 %then %do;
  libname &outlib JSON fileref=&fname2;
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
