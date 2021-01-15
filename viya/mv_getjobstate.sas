/**
  @file
  @brief Extract the status from a running SAS Viya job
  @details Extracts the status from a running job and writes it to a fileref.
  An output dataset is created like this:

      | uri                                                           | state   | timestamp          |
      |---------------------------------------------------------------|---------|--------------------|
      | /jobExecution/jobs/5cebd840-2063-42c1-be0c-421ec3e1c175/state | running | 15JAN2021:12:35:08 |

  ## Example

  First, compile the macros:

      filename mc url
      "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

  Create a long running job (in this case, a web service):

      filename ft15f001 temp;
      parmcards4;
        data ;
          rand=ranuni(0)*1000;
          do x=1 to rand;
            y=rand*4;
            output;
          end;
        run;
        data _null_;
          call sleep(5,1);
        run;
      ;;;;
      %mv_createwebservice(path=/Public/temp,name=demo)

  Execute it, grab the uri, and check status:

      %mv_jobexecute(path=/Public/temp
        ,name=demo
        ,outds=work.info
      )

      data _null_;
        set work.info;
        if method='GET' and rel='state';
        call symputx('uri',uri);
      run;

      %mv_getjobstate(uri=&uri,outds=results)


  @param [in] access_token_var= The global macro variable to contain the access token
  @param [in] grant_type= valid values:
      * password
      * authorization_code
      * detect - will check if access_token exists, if not will use sas_services if
        a SASStudioV session else authorization_code.  Default option.
      * sas_services - will use oauth_bearer=sas_services
  @param [in] uri= The uri of the running job for which to fetch the status,
    in the format `/jobExecution/jobs/$UUID/state` (unquoted).
  @param [out] outds= The output dataset in which to APPEND the status. Three
    fields are appended:  `CHECK_TM`, `URI` and `STATE`. If the dataset does not
    exist, it is created.


  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mf_getplatform.sas
  @li mf_getuniquefileref.sas

**/

%macro mv_getjobstate(uri=0,outds=work.mv_getjobstate
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

/* validation in datastep for better character safety */
%local errmsg errflg;
data _null_;
  uri=symget('uri');
  if length(uri)<12 then do;
    call symputx('errflg',1);
    call symputx('errmsg',"URI is invalid (too short) - '&uri'",'l');
  end;
  if scan(uri,-1) ne 'state' or scan(uri,1) ne 'jobExecution' then do;

    call symputx('errflg',1);
    call symputx('errmsg',
      "URI should be in format /jobExecution/jobs/$$$$UUID$$$$/state"
      !!" but is actually like: &uri",'l');
  end;
run;

%mp_abort(iftrue=(&errflg=1)
  ,mac=&sysmacroname
  ,msg=%str(&errmsg)
)

options noquotelenmax;
%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

%local fname0;
%let fname0=%mf_getuniquefileref();

proc http method='GET' out=&fname0 &oauth_bearer url="&base_uri/&uri";
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

data;
  format uri $128. state $32. timestamp datetime19.;
  infile &fname0;
  uri="&uri";
  timestamp=datetime();
  input;
  state=_infile_;
run;

proc append base=&outds data=&syslast;
run;

filename &fname0 clear;

%mend;
