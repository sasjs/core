/**
  @file
  @brief Takes a table of running jobs and waits for ANY/ALL of them to complete
  @details Will poll `/jobs/{jobId}/state` at set intervals until ANY or ALL
  jobs are completed.  Completion is determined by reference to the returned
  _state_, as per the following table:

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

      %mv_jobwaitfor(ALL,inds=work.jobs,outds=work.jobstates)

  Delete the job:

      %mv_deletejes(path=/Public/temp,name=demo)

  @param [in] access_token_var= The global macro variable to contain the access
    token
  @param [in] grant_type= valid values:

      - password
      - authorization_code
      - detect - will check if access_token exists, if not will use sas_services
        if a SASStudioV session else authorization_code.  Default option.
      - sas_services - will use oauth_bearer=sas_services

  @param [in] action=Either ALL (to wait for every job) or ANY (if one job
    completes, processing will continue).  Default=ALL.
  @param [in] inds= The input dataset containing the list of job uris, in the
    following format:  `/jobExecution/jobs/&JOBID./state` and the corresponding
    job name.  The uri should be in a `uri` variable, and the job path/name
    should be in a `_program` variable.
  @param [in] raise_err=0 Set to 1 to raise SYSCC when a job does not complete
              succcessfully
  @param [in] mdebug= set to 1 to enable DEBUG messages
  @param [out] outds= The output dataset containing the list of states by job
    (default=work.mv_jobexecute)
  @param [out] outref= A fileref to which the spawned job logs should be
    appended.

  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> Dependencies </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas
  @li mf_existvar.sas
  @li mf_nobs.sas
  @li mv_getjoblog.sas

**/

%macro mv_jobwaitfor(action
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,inds=0
    ,outds=work.mv_jobwaitfor
    ,outref=0
    ,raise_err=0
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
  length jobparams $32767;
  set &inds end=last;
  call symputx(cats('joburi',_n_),substr(uri,1,55),'l');
  call symputx(cats('jobname',_n_),_program,'l');
  call symputx(cats('jobparams',_n_),jobparams,'l');
  if last then call symputx('uricnt',_n_,'l');
run;

%local runcnt;
%if &action=ALL %then %let runcnt=&uricnt;
%else %if &action=ANY %then %let runcnt=1;
%else %let runcnt=&uricnt;

%local fname0 ;
%let fname0=%mf_getuniquefileref();

data &outds;
  format _program uri $128. state $32. stateDetails $32. timestamp datetime19.
    jobparams $32767.;
  call missing (of _all_);
  stop;
run;

%local i;
%do i=1 %to &uricnt;
  %if "&&joburi&i" ne "0" %then %do;
    proc http method='GET' out=&fname0 &oauth_bearer url="&base_uri/&&joburi&i";
      headers "Accept"="application/json"
      %if &grant_type=authorization_code %then %do;
              "Authorization"="Bearer &&&access_token_var"
      %end;  ;
    run;
    %if &SYS_PROCHTTP_STATUS_CODE ne 200 and &SYS_PROCHTTP_STATUS_CODE ne 201
    %then %do;
      data _null_;infile &fname0;input;putlog _infile_;run;
      %mp_abort(mac=&sysmacroname
        ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
      )
    %end;

    %let status=notset;

    %local libref1;
    %let libref1=%mf_getuniquelibref();
    libname &libref1 json fileref=&fname0;

    data _null_;
      length state stateDetails $32;
      set &libref1..root;
      call symputx('status',state,'l');
      call symputx('stateDetails',stateDetails,'l');
    run;

    libname &libref1 clear;

    %if &status=completed or &status=failed or &status=canceled %then %do;
      %local plainuri;
      %let plainuri=%substr(&&joburi&i,1,55);
      proc sql;
      insert into &outds set
        _program="&&jobname&i",
        uri="&plainuri",
        state="&status",
        stateDetails=symget("stateDetails"),
        timestamp=datetime(),
        jobparams=symget("jobparams&i");
      %let joburi&i=0; /* do not re-check */
      /* fetch log */
      %if %str(&outref) ne 0 %then %do;
        %mv_getjoblog(uri=&plainuri,outref=&outref,mdebug=&mdebug)
      %end;
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

    %if (&raise_err) %then %do;
      %if (&status = canceled or &status = failed or %length(&stateDetails)>0)
      %then %do;
        %if ("&stateDetails" = "%str(war)ning") %then %let SYSCC=4;
        %else %let SYSCC=5;
        %put %str(ERR)OR: Job &&jobname&i. did not complete. &stateDetails;
        %return;
      %end;
    %end;

  %end;
  %if &i=&uricnt %then %do;
    %local goback;
    %let goback=0;
    proc sql noprint;
    select count(*) into:goback from &outds;
    %if &goback lt &runcnt %then %let i=0;
  %end;
%end;

%if &mdebug=1 %then %do;
  %put &sysmacroname exit vars:;
  %put _local_;
%end;
%else %do;
  /* clear refs */
  filename &fname0 clear;
%end;
%mend mv_jobwaitfor;