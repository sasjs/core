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

**/

%macro mv_getjobcode(outref=0,outfile=0
    ,name=0,path=0
    ,contextName=SAS Job Execution compute context
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,mdebug=0
  );
%local dbg bufsize varcnt fname1 fname2 errmsg;
%if &mdebug=1 %then %do;
  %put &sysmacroname local entry vars:;
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
  length name uri $512;
  call missing(name,uri);
  set &foldermembers;
  if name="&name" and uri=:'/jobDefinitions/definitions'
    then call symputx('joburi',uri);
run;
%mp_abort(iftrue=("&joburi"="0")
  ,mac=&sysmacroname
  ,msg=%str(Job &path/&name not found)
)

/* prepare request*/
%let fname1=%mf_getuniquefileref();
proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri&joburi";
  headers "Accept"="application/vnd.sas.job.definition+json"
  %if &grant_type=authorization_code %then %do;
          "Authorization"="Bearer &&&access_token_var"
  %end;
  ;
run;

%if &mdebug=1 %then %do;
  data _null_;
    infile &fname1;
    input;
    putlog _infile_;
  run;
%end;

%mp_abort(
  iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200 and &SYS_PROCHTTP_STATUS_CODE ne 201)
  ,mac=&sysmacroname
  ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)

%let fname2=%mf_getuniquefileref();
filename &fname2 temp ;

/* cannot use lua IO package as not available in Viya 4 */
/* so use data step to read the JSON until the string `"code":"` is found */
data _null_;
  file &fname2 recfm=n;
  infile &fname1 lrecl=1 recfm=n;
  input sourcechar $char1. @@;
  format sourcechar hex2.;
  retain startwrite 0;
  if startwrite=0 and sourcechar='"' then do;
    reentry:
    input sourcechar $ 1. @@;
    if sourcechar='c' then do;
      reentry2:
      input sourcechar $ 1. @@;
      if sourcechar='o' then do;
        input sourcechar $ 1. @@;
        if sourcechar='d' then do;
          input sourcechar $ 1. @@;
          if sourcechar='e' then do;
            input sourcechar $ 1. @@;
            if sourcechar='"' then do;
              input sourcechar $ 1. @@;
              if sourcechar=':' then do;
                input sourcechar $ 1. @@;
                if sourcechar='"' then do;
                  putlog 'code found';
                  startwrite=1;
                  input sourcechar $ 1. @@;
                end;
              end;
              else if sourcechar='c' then goto reentry2;
            end;
          end;
          else if sourcechar='"' then goto reentry;
        end;
        else if sourcechar='"' then goto reentry;
      end;
      else if sourcechar='"' then goto reentry;
    end;
    else if sourcechar='"' then goto reentry;
  end;
  /* once the `"code":"` string is found, write until unescaped `"` is found */
  if startwrite=1 then do;
    if sourcechar='\' then do;
      input sourcechar $ 1. @@;
      if sourcechar in ('"','\') then put sourcechar char1.;
      else if sourcechar='n' then put '0A'x;
      else if sourcechar='r' then put '0D'x;
      else if sourcechar='t' then put '09'x;
      else if sourcechar='u' then do;
        length uni $4;
        input uni $ 4. @@;
        sourcechar=unicode('\u'!!uni);
        put sourcechar char1.;
      end;
      else do;
        call symputx('errmsg',"Uncaught escape char: "!!sourcechar,'l');
        call symputx('syscc',99);
        stop;
      end;
    end;
    else if sourcechar='"' then stop;
    else put sourcechar char1.;
  end;
run;

%mp_abort(iftrue=("&syscc"="99")
  ,mac=mv_getjobcode
  ,msg=%str(&errmsg)
)

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
%end;

%mend mv_getjobcode;
