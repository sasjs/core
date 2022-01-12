/**
  @file
  @brief Execute a series of job flows
  @details Very (very) simple flow manager.  Jobs execute in sequential waves,
  all previous waves must finish successfully.

  The input table is formed as per below.  Each observation represents one job.
  Each variable is converted into a macro variable with the same name.

  ## Input table (minimum variables needed)

  @li _PROGRAM - Provides the path to the job itself
  @li FLOW_ID - Numeric value, provides sequential ordering capability. Is
    optional, will default to 0 if not provided.
  @li _CONTEXTNAME - Dictates which context should be used to run the job. If
    blank, or not provided, will default to `SAS Job Execution compute context`.

  Any additional variables provided in this table are converted into macro
  variables and passed into the relevant job.

  |_PROGRAM| FLOW_ID (optional)| _CONTEXTNAME (optional) |
  |---|---|---|
  |/Public/jobs/somejob1|0|SAS Job Execution compute context|
  |/Public/jobs/somejob2|0|SAS Job Execution compute context|

  ## Output table (minimum variables produced)

  @li _PROGRAM - the SAS Drive path of the job
  @li URI - the URI of the executed job
  @li STATE - the completed state of the job
  @li TIMESTAMP - the datetime that the job completed
  @li JOBPARAMS - the parameters that were passed to the job
  @li FLOW_ID - the id of the flow in which the job was executed

  ![https://i.imgur.com/nZE9PvT.png](https://i.imgur.com/nZE9PvT.png)

  To avoid hammering the box with many hits in rapid succession, a one
  second pause is made between every request.


  ## Example

  First, compile the macros:

      filename mc url
      "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

  Next, create some jobs (in this case, as web services):

      filename ft15f001 temp;
      parmcards4;
        %put this is job: &_program;
        %put this was run in flow &flow_id;
        data ;
          rand=ranuni(0)*&macrovar1;
          do x=1 to rand;
            y=rand*&macrovar2;
            if y=100 then abort;
            output;
          end;
        run;
      ;;;;
      %mv_createwebservice(path=/Public/temp,name=demo1)
      %mv_createwebservice(path=/Public/temp,name=demo2)

  Prepare an input table with 60 executions:

      data work.inputjobs;
        _contextName='SAS Job Execution compute context';
        do flow_id=1 to 3;
          do i=1 to 20;
            _program='/Public/temp/demo1';
            macrovar1=10*i;
            macrovar2=4*i;
            output;
            i+1;
            _program='/Public/temp/demo2';
            macrovar1=40*i;
            macrovar2=44*i;
            output;
          end;
        end;
      run;

  Trigger the flow

      %mv_jobflow(inds=work.inputjobs
        ,maxconcurrency=4
        ,outds=work.results
        ,outref=myjoblog
      )

      data _null_;
        infile myjoblog;
        input; put _infile_;
      run;


  @param [in] access_token_var= The global macro variable to contain the
              access token
  @param [in] grant_type= valid values:
      @li password
      @li authorization_code
      @li detect - will check if access_token exists, if not will use
        sas_services if a SASStudioV session else authorization_code.  Default
        option.
      @li sas_services - will use oauth_bearer=sas_services
  @param [in] inds= The input dataset containing a list of jobs and parameters
  @param [in] maxconcurrency= The max number of parallel jobs to run. Default=8.
  @param [in] raise_err=0 Set to 1 to raise SYSCC when a job does not complete
            succcessfully
  @param [in] mdebug= set to 1 to enable DEBUG messages
  @param [out] outds= The output dataset containing the results
  @param [out] outref= The output fileref to which to append the log file(s).

  @version VIYA V.03.05
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> SAS Macros </h4>
  @li mf_nobs.sas
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas
  @li mf_existvarlist.sas
  @li mv_jobwaitfor.sas
  @li mv_jobexecute.sas

**/

%macro mv_jobflow(inds=0,outds=work.mv_jobflow
    ,maxconcurrency=8
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,outref=0
    ,raise_err=0
    ,mdebug=0
  );
%local dbg;
%if &mdebug=1 %then %do;
  %put &sysmacroname entry vars:;
  %put _local_;
  %put inds vars:;
  data _null_;
    set &inds;
    putlog (_all_)(=);
  run;
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
  ,msg=%str(Input dataset was not provided)
)
%mp_abort(iftrue=(%mf_existVarList(&inds,_PROGRAM)=0)
  ,mac=&sysmacroname
  ,msg=%str(The _PROGRAM column must exist on input dataset &inds)
)
%mp_abort(iftrue=(&maxconcurrency<1)
  ,mac=&sysmacroname
  ,msg=%str(The maxconcurrency variable should be a positive integer)
)

/* set defaults if not provided */
%if %mf_existVarList(&inds,_CONTEXTNAME FLOW_ID)=0 %then %do;
  data &inds;
    %if %mf_existvarList(&inds,_CONTEXTNAME)=0 %then %do;
      length _CONTEXTNAME $128;
      retain _CONTEXTNAME "SAS Job Execution compute context";
    %end;
    %if %mf_existvarList(&inds,FLOW_ID)=0 %then %do;
      retain FLOW_ID 0;
    %end;
    set &inds;
    &dbg. putlog (_all_)(=);
  run;
%end;

%local missings;
proc sql noprint;
select count(*) into: missings
  from &inds
  where flow_id is null or _program is null;
%mp_abort(iftrue=(&missings>0)
  ,mac=&sysmacroname
  ,msg=%str(input dataset has &missings missing values for FLOW_ID or _PROGRAM)
)

%if %mf_nobs(&inds)=0 %then %do;
  %put No observations in &inds!  Leaving macro &sysmacroname;
  %return;
%end;

/* ensure output table is available */
data &outds;run;
proc sql;
drop table &outds;

options noquotelenmax;
%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);


/* get flows */
proc sort data=&inds;
  by flow_id;
run;
data _null_;
  set &inds (keep=flow_id) end=last;
  by flow_id;
  if last.flow_id then do;
    cnt+1;
    call symputx(cats('flow',cnt),flow_id,'l');
  end;
  if last then call symputx('flowcnt',cnt,'l');
run;

/* prepare temporary datasets and frefs */
%local fid jid jds jjson jdsapp jdsrunning jdswaitfor jfref;
data;run;%let jds=&syslast;
data;run;%let jjson=&syslast;
data;run;%let jdsapp=&syslast;
data;run;%let jdsrunning=&syslast;
data;run;%let jdswaitfor=&syslast;
%let jfref=%mf_getuniquefileref();

/* start loop */
%do fid=1 %to &flowcnt;

  %if not ( &raise_err and &syscc ) %then %do;

    %put preparing job attributes for flow &&flow&fid;
    %local jds jcnt;
    data &jds(drop=_contextName _program);
      set &inds(where=(flow_id=&&flow&fid));
      if _contextName='' then _contextName="SAS Job Execution compute context";
      call symputx(cats('job',_n_),_program,'l');
      call symputx(cats('context',_n_),_contextName,'l');
      call symputx('jcnt',_n_,'l');
      &dbg. if _n_= 1 then putlog "Loop &fid";
      &dbg. putlog (_all_)(=);
    run;
    %put exporting job variables in json format;
    %do jid=1 %to &jcnt;
      data &jjson;
        set &jds;
        if _n_=&jid then do;
          output;
          stop;
        end;
      run;
      proc json out=&jfref;
        export &jjson / nosastags fmtnumeric;
      run;
      data _null_;
        infile &jfref lrecl=32767;
        input;
        jparams=cats('jparams',symget('jid'));
        call symputx(jparams,substr(_infile_,3,length(_infile_)-4));
      run;
      %local jobuid&jid;
      %let jobuid&jid=0; /* used in next loop */
    %end;
    %local concurrency completed;
    %let concurrency=0;
    %let completed=0;
    proc sql; drop table &jdsrunning;
    %do jid=1 %to &jcnt;
      /**
        * now we can execute the jobs up to the maxconcurrency setting
        */
      %if "&&job&jid" ne "0" %then %do; /* this var is zero if job finished */

        /* check to see if the job finished in the previous round */
        %if %sysfunc(exist(&outds))=1 %then %do;
          %local jobcheck;  %let jobcheck=0;
          proc sql noprint;
          select count(*) into: jobcheck
            from &outds where uuid="&&jobuid&jid";
          %if &jobcheck>0 %then %do;
            %put &&job&jid in flow &fid with uid &&jobuid&jid completed!;
            %let job&jid=0;
          %end;
        %end;

        /* check if job was triggered and, if
            so, if we have enough slots to run? */
        %if ("&&jobuid&jid"="0") and (&concurrency<&maxconcurrency) %then %do;

          /* But only start if no issues detected so far */
          %if not ( &raise_err and &syscc ) %then %do;

            %local jobname jobpath;
            %let jobname=%scan(&&job&jid,-1,/);
            %let jobpath=
                  %substr(&&job&jid,1,%length(&&job&jid)-%length(&jobname)-1);

            %put executing &jobpath/&jobname with paramstring &&jparams&jid;
            %mv_jobexecute(path=&jobpath
              ,name=&jobname
              ,paramstring=%superq(jparams&jid)
              ,outds=&jdsapp
              ,contextname=&&context&jid
            )
            data &jdsapp;
              format jobparams $32767.;
              set &jdsapp(where=(method='GET' and rel='state'));
              jobparams=symget("jparams&jid");
              /* uri here has the /state suffix */
              uuid=scan(uri,-2,'/');
              call symputx("jobuid&jid",uuid,'l');
            run;
            proc append base=&jdsrunning data=&jdsapp;
            run;
            %let concurrency=%eval(&concurrency+1);
            /* sleep one second after every request to smooth the impact */
            data _null_;
              call sleep(1,1);
            run;

          %end;
          %else %do; /* Job was skipped due to problems */

            %put jobid &&job&jid in flow &fid skipped due to SYSCC (&syscc);
            %let completed = %eval(&completed+1);
            %let job&jid=0; /* Indicate job has finished */

          %end;

        %end;
      %end;
      %if &jid=&jcnt %then %do;
        /* we are at the end of the loop - check which jobs have finished */
        %mv_jobwaitfor(ANY,inds=&jdsrunning,outds=&jdswaitfor,outref=&outref
                      ,raise_err=&raise_err,mdebug=&mdebug)
        %local done;
        %let done=%mf_nobs(&jdswaitfor);
        %if &done>0 %then %do;
          %let completed=%eval(&completed+&done);
          %let concurrency=%eval(&concurrency-&done);
          data &jdsapp;
            set &jdswaitfor;
            flow_id=&&flow&fid;
            uuid=scan(uri,-1,'/');
          run;
          proc append base=&outds data=&jdsapp;
          run;
        %end;
        proc sql;
        delete from &jdsrunning
          where uuid in (select uuid from &outds
            where state in ('canceled','completed','failed')
          );

        /* loop again if jobs are left */
        %if &completed < &jcnt %then %do;
          %let jid=0;
          %put looping flow &fid again;
          %put &completed of &jcnt jobs completed, &concurrency jobs running;
        %end;
      %end;
    %end;

  %end;
  %else %do;

    %put Flow &&flow&fid skipped due to SYSCC (&syscc);

  %end;
  /* back up and execute the next flow */
%end;

%if &mdebug=1 %then %do;
  %put &sysmacroname exit vars:;
  %put _local_;
%end;

%mend mv_jobflow;
