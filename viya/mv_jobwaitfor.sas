/**
  @file
  @brief Takes a dataset of running jobs and waits for them to complete
  @details Will poll `/jobs/{jobId}/state` at set intervals until they are all
  completed.  Completion is determined by reference to the returned _state_, as
  per the following table:

  | state     | Wait? | Notes|
  |-----------|-------|------|
  | idle      | yes   | We assume processing will continue. Beware of idle sessions with no code submitted! |
  | pending   | yes   | Job is preparing to run |
  | running   | yes   | Job is running|
  | canceled  | no    | Job was cancelled|
  | completed | no    | Job finished - does not mean it was successful.  Check stateDetails|
  | failed    | no    | Job failed to execute, could be a problem when calling the apis|


  ## Example

  First, compile the macros:

      filename mc url
      "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

  Next, create a job (in this case, as a web service):

      filename ft15f001 temp;
      parmcards4;
        data ;
          rand=ranuni(0)*1000000;
          do x=1 to rand;
            y=rand*x;
            output;
          end;
        run;
      ;;;;
      %mv_createwebservice(path=/Public/temp,name=demo)

  Then, execute the job,multiple times, and wait for them all to finish:

      %mv_jobexecute(path=/Public/temp,name=demo,outds=work.ds1)
      %mv_jobexecute(path=/Public/temp,name=demo,outds=work.ds2)
      %mv_jobexecute(path=/Public/temp,name=demo,outds=work.ds3)
      %mv_jobexecute(path=/Public/temp,name=demo,outds=work.ds4)

      data work.jobs;
        set work.ds1 work.ds2 work.ds3 work.ds4;
        where method='GET' and rel='state';
      run;

      %mv_jobwaitfor(inds=work.jobs,outds=work.jobstates)


  Delete the job:

      %mv_deletejes(path=/Public/temp,name=demo)

  @param [in] access_token_var= The global macro variable to contain the access token
  @param [in] grant_type= valid values:

      - password
      - authorization_code
      - detect - will check if access_token exists, if not will use sas_services if
        a SASStudioV session else authorization_code.  Default option.
      - sas_services - will use oauth_bearer=sas_services

  @param [in] inds= The input dataset containing the list of job uris, in the
    following format:  `/jobExecution/jobs/&JOBID./state` and the corresponding
    job name.  The uri should be in a `uri` variable, and the job path/name
    should be in a `_program` variable.
  @param [out] outds= The output dataset containing the list of states by job
    (default=work.mv_jobexecute)


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_existvar.sas
  @li mf_nobs.sas

**/

%macro mv_jobwaitfor(
     access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,inds=0
    ,outds=work.mv_jobwaitfor
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

%mp_abort(iftrue=("&inds"="0")
  ,mac=&sysmacroname
  ,msg=%str(input dataset not provided)
)
%mp_abort(iftrue=(%mf_existvar(&inds,uri)=0)
  ,mac=&sysmacroname
  ,msg=%str(The URI variable was not found in the input dataset(&inds))
)
%mp_abort(iftrue=(%mf_existvar(&inds,_program)=0)
  ,mac=&sysmacroname
  ,msg=%str(The _PROGRAM variable was not found in the input dataset(&inds))
)

%if %mf_nobs(&inds)=0 %then %do;
  %put NOTE: Zero observations in &inds, &sysmacroname will now exit;
  %return;
%end;

options noquotelenmax;
%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

data _null_;
  set &inds end=last;
  call symputx(cats('joburi',_n_),uri,'l');
  call symputx(cats('jobname',_n_),_program,'l');
  if last then call symputx('uricnt',_n_,'l');
run;

%local fname0 ;
%let fname0=%mf_getuniquefileref();

data &outds;
  format _program uri $128. state $32. timestamp datetime19.;
  stop;
run;

%local i;
%do i=1 %to &uricnt;
  %if "&&joburi&i" ne "0" %then %do;
    proc http method='GET' out=&fname0 &oauth_bearer url="&base_uri/&&joburi&i";
      headers "Accept"="text/plain"
      %if &grant_type=authorization_code %then %do;
              "Authorization"="Bearer &&&access_token_var"
      %end;  ;
    run;
    %if &SYS_PROCHTTP_STATUS_CODE ne 200 and &SYS_PROCHTTP_STATUS_CODE ne 201 %then
    %do;
      data _null_;infile &fname0;input;putlog _infile_;run;
      %mp_abort(mac=&sysmacroname
        ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
      )
    %end;

    %let status=notset;
    data _null_;
      infile &fname0;
      input;
      call symputx('status',_infile_,'l');
    run;

    %if &status=completed or &status=failed or &status=canceled %then %do;
      proc sql;
      insert into &outds set
        _program="&&jobname&i",
        uri="&&joburi&i",
        state="&status",
        timestamp=datetime();
      %let joburi&i=0;
    %end;
    %else %if &status=idle or &status=pending or &status=running %then %do;
      data _null_;
        call sleep(1,1);
      run;
    %end;
    %else %do;
      %mp_abort(mac=&sysmacroname
        ,msg=%str(status &status not expected!!)
      )
    %end;
  %end;
  %if &i=&uricnt %then %do;
    %local goback;
    %let goback=0;
    proc sql noprint;
    select count(*) into:goback from &outds;
    %if &goback ne &uricnt %then %let i=0;
  %end;
%end;

/* clear refs */
filename &fname0 clear;

%mend;