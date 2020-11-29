/**
  @file
  @brief Executes a SAS Viya Job
  @details Triggers a SAS Viya Job, with optional URL parameters, using
  the JES web app.

  First, compile the macros:

      filename mc url
      "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

  Then, execute the job!

      %mv_jobexecute(path=/Public/folder
        ,name=somejob
      )


  @param access_token_var= The global macro variable to contain the access token
  @param grant_type= valid values:
   * password
   * authorization_code
   * detect - will check if access_token exists, if not will use sas_services if
    a SASStudioV session else authorization_code.  Default option.
   * sas_services - will use oauth_bearer=sas_services

  @param path= The SAS Drive path to the job being executed
  @param name= The name of the job to execute
  @param params= A macro quoted string to append to the URL
  @param contextName= Context name with which to run the job.
    Default = `SAS Job Execution compute context`


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mv_getfoldermembers.sas

**/

%macro mv_jobexecute(path=0
    ,name=0
    ,contextName=SAS Job Execution compute context
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
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

%mp_abort(iftrue=("&path"="0")
  ,mac=&sysmacroname
  ,msg=%str(Path not provided)
)
%mp_abort(iftrue=("&name"="0")
  ,mac=&sysmacroname
  ,msg=%str(Job Name not provided)
)

options noquotelenmax;

%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

data;run;
%local foldermembers;
%let foldermembers=&syslast;
%mv_getfoldermembers(root=&path
    ,access_token_var=&access_token_var
    ,grant_type=&grant_type
    ,outds=&foldermembers
)

%local joburi;
%let joburi=0;
data _null_;
  set &foldermembers;
  if name="&name" and uri=:'/jobDefinitions/definitions'
    then call symputx('joburi',uri);
run;

%mp_abort(iftrue=("&joburi"="0")
  ,mac=&sysmacroname
  ,msg=%str(Job &path/&name not found)
)

/* prepare request*/
%local fname0 fname1;
%let fname0=%mf_getuniquefileref();
%let fname1=%mf_getuniquefileref();

data _null_;
  file &fname0;
  put '{"jobDefinitionUri": "'@@;
  put "&joburi"@@;
  put '","arguments":{"_contextName":"'@@;
  put "&contextName"@@;
  put '"}}';
run;

proc http method='POST' in=&fname0 out=&fname1 &oauth_bearer
  url="&base_uri/jobExecution/jobs";
  headers "Content-Type"="application/vnd.sas.job.execution.job.request+json"
          "Accept"="application/vnd.sas.job.execution.job+json"
  %if &grant_type=authorization_code %then %do;
          "Authorization"="Bearer &&&access_token_var"
  %end;
  ;
run;
/*data _null_;infile &fname1;input;putlog _infile_;run;*/

%mp_abort(iftrue=(
    &SYS_PROCHTTP_STATUS_CODE ne 200 and &SYS_PROCHTTP_STATUS_CODE ne 201
  )
  ,mac=&sysmacroname
  ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)

/* clear refs */
filename &fname0 clear;
filename &fname1 clear;

%mend;