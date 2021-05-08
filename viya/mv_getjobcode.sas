/**
  @file
  @brief Extract the source code from a SAS Viya Job
  @details Extracts the SAS code from a Job into a fileref or physical file.
  Example:

      %mv_getjobcode(
        path=/Public/jobs
        ,name=some_job
        ,outfile=/tmp/some_job.sas
      )

  @param [in] access_token_var= The global macro variable to contain the access
    token
  @param [in] grant_type= valid values:
    @li password
    @liauthorization_code
    @li detect - will check if access_token exists, if not will use sas_services
      if a SASStudioV session else authorization_code.  Default option.
    @li  sas_services - will use oauth_bearer=sas_services
  @param [in] path= The SAS Drive path of the job
  @param [in] name= The name of the job
  @param [in] mdebug=(0) set to 1 to enable DEBUG messages
  @param [out] outref=(0) A fileref to which to write the source code (will be
    created with a TEMP engine)
  @param [out] outfile=(0) A file to which to write the source code

  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mv_getfoldermembers.sas
  @li ml_json.sas

**/

%macro mv_getjobcode(outref=0,outfile=0
    ,name=0,path=0
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
%mp_abort(iftrue=("&path"="0")
  ,mac=&sysmacroname
  ,msg=%str(Job Path not provided)
)
%mp_abort(iftrue=("&name"="0")
  ,mac=&sysmacroname
  ,msg=%str(Job Name not provided)
)
%mp_abort(iftrue=("&outfile"="0" and "&outref"="0")
  ,mac=&sysmacroname
  ,msg=%str(Output destination (file or fileref) must be provided)
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
%local  fname1;
%let fname1=%mf_getuniquefileref();
proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri&joburi";
  headers "Accept"="application/vnd.sas.job.definition+json"
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
    local job=resp["code"]
    outfile:write(job)
    io.close(infile)
    io.close(outfile)
  ';
run;
%inc "&fpath3..lua";
/* export to desired destination */
%if "&outref"="0" %then %do;
  data _null_;
    file "&outfile" lrecl=32767;
%end;
%else %do;
  filename &outref temp;
  data _null_;
    file &outref;
%end;
  infile &fname2;
  input;
  put _infile_;
  &dbg. putlog _infile_;
run;

%if &mdebug=1 %then %do;
  %put &sysmacroname exit vars:;
  %put _local_;
%end;
%else %do;
  /* clear refs */
  filename &fname1 clear;
  filename &fname2 clear;
  filename &fname3 clear;
%end;

%mend mv_getjobcode;
