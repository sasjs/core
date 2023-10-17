/**
  @file
  @brief Creates a JobExecution web service if it doesn't already exist
  @details
  Code is passed in as one or more filerefs.

      %* Step 1 - compile macros ;
      filename mc url
        "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
      %inc mc;

      %* Step 2 - Create some code and add it to a web service;
      filename ft15f001 temp;
      parmcards4;
          %webout(FETCH) %* fetch any tables sent from frontend;
          %* do some sas, any inputs are now already WORK tables;
          data example1 example2;
            set sashelp.class;
          run;
          %* send data back;
          %webout(OPEN)
          %webout(ARR,example1) * Array format, fast, suitable for large tables;
          %webout(OBJ,example2) * Object format, easier to work with ;
          %webout(CLOSE)
      ;;;;
      %mv_createwebservice(path=/Public/app/common,name=appinit)


  Notes:
    To minimise postgres requests, output json is stored in a temporary file
    and then sent to _webout in one go at the end.

  <h4> SAS Macros </h4>
  @li mp_abort.sas
  @li mv_createfolder.sas
  @li mf_getuniquelibref.sas
  @li mf_getuniquefileref.sas
  @li mf_getplatform.sas
  @li mf_isblank.sas
  @li mv_deletejes.sas

  @param [in] path= The full path (on SAS Drive) where the service will be
    created
  @param [in] name= The name of the service
  @param [in] desc= The description of the service
  @param [in] precode= Space separated list of filerefs, pointing to the code
    that needs to be attached to the beginning of the service
  @param [in] code= Fileref(s) of the actual code to be added
  @param [in] access_token_var= The global macro variable to contain the access
    token
  @param [in] grant_type= valid values are "password" or "authorization_code"
    (unquoted). The default is authorization_code.
  @param [in] replace=(YES) Select NO to avoid replacing any existing service in
    that location
  @param [in] adapter= the macro uses the sasjs adapter by default.  To use
    another adapter, add a (different) fileref here.
  @param [in] contextname= Choose a specific context on which to run the Job.
    Leave blank to use the default context.  From Viya 3.5 it is possible to
    configure a shared context - see
https://go.documentation.sas.com/?docsetId=calcontexts&docsetTarget=n1hjn8eobk5pyhn1wg3ja0drdl6h.htm&docsetVersion=3.5&locale=en
  @param [in] mdebug=(0) set to 1 to enable DEBUG messages

  @version VIYA V.03.04
  @author Allan Bowe, source: https://github.com/sasjs/core

**/

%macro mv_createwebservice(path=
    ,name=
    ,desc=Created by the mv_createwebservice.sas macro
    ,precode=
    ,code=ft15f001
    ,access_token_var=ACCESS_TOKEN
    ,grant_type=sas_services
    ,replace=YES
    ,adapter=sasjs
    ,mdebug=0
    ,contextname=
    ,debug=0 /* @TODO - Deprecate */
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

/* initial validation checking */
%mp_abort(iftrue=(&grant_type ne authorization_code and &grant_type ne password
    and &grant_type ne sas_services
  )
  ,mac=&sysmacroname
  ,msg=%str(Invalid value for grant_type: &grant_type)
)
%mp_abort(iftrue=(%mf_isblank(&path)=1)
  ,mac=&sysmacroname
  ,msg=%str(path value must be provided)
)
%mp_abort(iftrue=(%length(&path)=1)
  ,mac=&sysmacroname
  ,msg=%str(path value must be provided)
)
%mp_abort(iftrue=(%mf_isblank(&name)=1)
  ,mac=&sysmacroname
  ,msg=%str(name value must be provided)
)

options noquotelenmax;

* remove any trailing slash ;
%if "%substr(&path,%length(&path),1)" = "/" %then
  %let path=%substr(&path,1,%length(&path)-1);

/* ensure folder exists */
%put &sysmacroname: Path &path being checked / created;
%mv_createfolder(path=&path)

%local base_uri; /* location of rest apis */
%let base_uri=%mf_getplatform(VIYARESTAPI);

/* fetching folder details for provided path */
%local fname1;
%let fname1=%mf_getuniquefileref();
proc http method='GET' out=&fname1 &oauth_bearer
  url="&base_uri/folders/folders/@item?path=&path";
%if &grant_type=authorization_code %then %do;
  headers "Authorization"="Bearer &&&access_token_var";
%end;
run;
%if &mdebug=1 %then %do;
  data _null_;
    infile &fname1;
    input;
    putlog _infile_;
  run;
%end;
%mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200)
  ,mac=&sysmacroname
  ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)

/* path exists. Grab follow on link to check members */
%local libref1;
%let libref1=%mf_getuniquelibref();
libname &libref1 JSON fileref=&fname1;

data _null_;
  set &libref1..links;
  if rel='members' then
    call symputx('membercheck',quote("&base_uri"!!trim(href)),'l');
  else if rel='self' then call symputx('parentFolderUri',href,'l');
run;
data _null_;
  set &libref1..root;
  call symputx('folderid',id,'l');
run;
%local fname2;
%let fname2=%mf_getuniquefileref();
proc http method='GET'
    out=&fname2
    &oauth_bearer
    url=%unquote(%superq(membercheck));
    headers
  %if &grant_type=authorization_code %then %do;
            "Authorization"="Bearer &&&access_token_var"
  %end;
            'Accept'='application/vnd.sas.collection+json'
            'Accept-Language'='string';
%if &mdebug=1 %then %do;
  debug level = 3;
%end;
run;
/*data _null_;infile &fname2;input;putlog _infile_;run;*/
%mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 200)
  ,mac=&sysmacroname
  ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)

%if %upcase(&replace)=YES %then %do;
  %mv_deletejes(path=&path, name=&name)
%end;
%else %do;
  /* check that job does not already exist in that folder */
  %local libref2;
  %let libref2=%mf_getuniquelibref();
  libname &libref2 JSON fileref=&fname2;
  %local exists; %let exists=0;
  data _null_;
    set &libref2..items;
    if contenttype='jobDefinition' and upcase(name)="%upcase(&name)" then
      call symputx('exists',1,'l');
  run;
  %mp_abort(iftrue=(&exists=1)
    ,mac=&sysmacroname
    ,msg=%str(Job &name already exists in &path)
  )
  libname &libref2 clear;
%end;

/* set up the body of the request to create the service */
%local fname3;
%let fname3=%mf_getuniquefileref();
data _null_;
  file &fname3 TERMSTR=' ';
  length string $32767;
  string=cats('{"version": 0,"name":"'
    ,"&name"
    ,'","type":"Compute","parameters":[{"name":"_addjesbeginendmacros"'
    ,',"type":"CHARACTER","defaultValue":"false"}');
  context=quote(cats(symget('contextname')));
  if context ne '""' then do;
    string=cats(string,',{"version": 1,"name": "_contextName","defaultValue":'
      ,context,',"type":"CHARACTER","label":"Context Name","required": false}');
  end;
  string=cats(string,'],"code":"');
  put string;
run;

/**
  * Add webout macro
  * These put statements are auto generated - to change the macro, change the
  * source (mv_webout) and run `build.py`
  */
filename &adapter temp lrecl=3000;
data _null_;
  file &adapter;
  put "/* Created on %sysfunc(datetime(),datetime19.) by &sysuserid */";
/* WEBOUT BEGIN */
  put '%macro mp_jsonout(action,ds,jref=_webout,dslabel=,fmt=Y ';
  put '  ,engine=DATASTEP ';
  put '  ,missing=NULL ';
  put '  ,showmeta=N ';
  put '  ,maxobs=MAX ';
  put ')/*/STORE SOURCE*/; ';
  put '%local tempds colinfo fmtds i numcols numobs stmt_obs lastobs optval ';
  put '  tmpds1 tmpds2 tmpds3 tmpds4; ';
  put '%let numcols=0; ';
  put '%if &maxobs ne MAX %then %let stmt_obs=%str(if _n_>&maxobs then stop;); ';
  put ' ';
  put '%if &action=OPEN %then %do; ';
  put '  options nobomfile; ';
  put '  data _null_;file &jref encoding=''utf-8'' lrecl=200; ';
  put '    put ''{"PROCESSED_DTTM" : "'' "%sysfunc(datetime(),E8601DT26.6)" ''"''; ';
  put '  run; ';
  put '%end; ';
  put '%else %if (&action=ARR or &action=OBJ) %then %do; ';
  put '  /* force variable names to always be uppercase in the JSON */ ';
  put '  options validvarname=upcase; ';
  put '  /* To avoid issues with _webout on EBI - such as encoding diffs and truncation ';
  put '    (https://support.sas.com/kb/49/325.html) we use temporary files */ ';
  put '  filename _sjs1 temp lrecl=200 ; ';
  put '  data _null_; file _sjs1 encoding=''utf-8''; ';
  put '    put ", ""%lowcase(%sysfunc(coalescec(&dslabel,&ds)))"":"; ';
  put '  run; ';
  put '  /* now write to _webout 1 char at a time */ ';
  put '  data _null_; ';
  put '    infile _sjs1 lrecl=1 recfm=n; ';
  put '    file &jref mod lrecl=1 recfm=n; ';
  put '    input sourcechar $char1. @@; ';
  put '    format sourcechar hex2.; ';
  put '    put sourcechar char1. @@; ';
  put '  run; ';
  put '  filename _sjs1 clear; ';
  put ' ';
  put '  /* grab col defs */ ';
  put '  proc contents noprint data=&ds ';
  put '    out=_data_(keep=name type length format formatl formatd varnum label); ';
  put '  run; ';
  put '  %let colinfo=%scan(&syslast,2,.); ';
  put '  proc sort data=&colinfo; ';
  put '    by varnum; ';
  put '  run; ';
  put '  /* move meta to mac vars */ ';
  put '  data &colinfo; ';
  put '    if _n_=1 then call symputx(''numcols'',nobs,''l''); ';
  put '    set &colinfo end=last nobs=nobs; ';
  put '    name=upcase(name); ';
  put '    /* fix formats */ ';
  put '    if type=2 or type=6 then do; ';
  put '      typelong=''char''; ';
  put '      length fmt $49.; ';
  put '      if format='''' then fmt=cats(''$'',length,''.''); ';
  put '      else if formatl=0 then fmt=cats(format,''.''); ';
  put '      else fmt=cats(format,formatl,''.''); ';
  put '    end; ';
  put '    else do; ';
  put '      typelong=''num''; ';
  put '      if format='''' then fmt=''best.''; ';
  put '      else if formatl=0 then fmt=cats(format,''.''); ';
  put '      else if formatd=0 then fmt=cats(format,formatl,''.''); ';
  put '      else fmt=cats(format,formatl,''.'',formatd); ';
  put '    end; ';
  put '    /* 32 char unique name */ ';
  put '    newname=''sasjs''!!substr(cats(put(md5(name),$hex32.)),1,27); ';
  put ' ';
  put '    call symputx(cats(''name'',_n_),name,''l''); ';
  put '    call symputx(cats(''newname'',_n_),newname,''l''); ';
  put '    call symputx(cats(''length'',_n_),length,''l''); ';
  put '    call symputx(cats(''fmt'',_n_),fmt,''l''); ';
  put '    call symputx(cats(''type'',_n_),type,''l''); ';
  put '    call symputx(cats(''typelong'',_n_),typelong,''l''); ';
  put '    call symputx(cats(''label'',_n_),coalescec(label,name),''l''); ';
  put '    /* overwritten when fmt=Y and a custom format exists in catalog */ ';
  put '    if typelong=''num'' then call symputx(cats(''fmtlen'',_n_),200,''l''); ';
  put '    else call symputx(cats(''fmtlen'',_n_),min(32767,ceil((length+10)*1.5)),''l''); ';
  put '  run; ';
  put ' ';
  put '  %let tempds=%substr(_%sysfunc(compress(%sysfunc(uuidgen()),-)),1,32); ';
  put '  proc sql; ';
  put '  select count(*) into: lastobs from &ds; ';
  put '  %if &maxobs ne MAX %then %let lastobs=%sysfunc(min(&lastobs,&maxobs)); ';
  put ' ';
  put '  %if &engine=PROCJSON %then %do; ';
  put '    %if &missing=STRING %then %do; ';
  put '      %put &sysmacroname: Special Missings not supported in proc json.; ';
  put '      %put &sysmacroname: Switching to DATASTEP engine; ';
  put '      %goto datastep; ';
  put '    %end; ';
  put '    data &tempds; ';
  put '      set &ds; ';
  put '      &stmt_obs; ';
  put '    %if &fmt=N %then format _numeric_ best32.;; ';
  put '    /* PRETTY is necessary to avoid line truncation in large files */ ';
  put '    filename _sjs2 temp lrecl=131068 encoding=''utf-8''; ';
  put '    proc json out=_sjs2 pretty ';
  put '        %if &action=ARR %then nokeys ; ';
  put '        ;export &tempds / nosastags fmtnumeric; ';
  put '    run; ';
  put '    /* send back to webout */ ';
  put '    data _null_; ';
  put '      infile _sjs2 lrecl=1 recfm=n; ';
  put '      file &jref mod lrecl=1 recfm=n; ';
  put '      input sourcechar $char1. @@; ';
  put '      format sourcechar hex2.; ';
  put '      put sourcechar char1. @@; ';
  put '    run; ';
  put '    filename _sjs2 clear; ';
  put '  %end; ';
  put '  %else %if &engine=DATASTEP %then %do; ';
  put '    %datastep: ';
  put '    %if %sysfunc(exist(&ds)) ne 1 & %sysfunc(exist(&ds,VIEW)) ne 1 ';
  put '    %then %do; ';
  put '      %put &sysmacroname:  &ds NOT FOUND!!!; ';
  put '      %return; ';
  put '    %end; ';
  put ' ';
  put '    %if &fmt=Y %then %do; ';
  put '      /** ';
  put '        * Extract format definitions ';
  put '        * First, by getting library locations from dictionary.formats ';
  put '        * Then, by exporting the width using proc format ';
  put '        * Cannot use maxw from sashelp.vformat as not always populated ';
  put '        * Cannot use fmtinfo() as not supported in all flavours ';
  put '        */ ';
  put '      %let tmpds1=%substr(fmtsum%sysfunc(compress(%sysfunc(uuidgen()),-)),1,32); ';
  put '      %let tmpds2=%substr(cntl%sysfunc(compress(%sysfunc(uuidgen()),-)),1,32); ';
  put '      %let tmpds3=%substr(cntl%sysfunc(compress(%sysfunc(uuidgen()),-)),1,32); ';
  put '      %let tmpds4=%substr(col%sysfunc(compress(%sysfunc(uuidgen()),-)),1,32); ';
  put '      proc sql noprint; ';
  put '      create table &tmpds1 as ';
  put '          select cats(libname,''.'',memname) as FMTCAT, ';
  put '          FMTNAME ';
  put '        from dictionary.formats ';
  put '        where fmttype=''F'' and libname is not null ';
  put '          and fmtname in (select format from &colinfo where format is not null) ';
  put '        order by 1; ';
  put '      create table &tmpds2( ';
  put '          FMTNAME char(32), ';
  put '          LENGTH num ';
  put '      ); ';
  put '      %local catlist cat fmtlist i; ';
  put '      select distinct fmtcat into: catlist separated by '' '' from &tmpds1; ';
  put '      %do i=1 %to %sysfunc(countw(&catlist,%str( ))); ';
  put '        %let cat=%scan(&catlist,&i,%str( )); ';
  put '        proc sql; ';
  put '        select distinct fmtname into: fmtlist separated by '' '' ';
  put '          from &tmpds1 where fmtcat="&cat"; ';
  put '        proc format lib=&cat cntlout=&tmpds3(keep=fmtname length); ';
  put '          select &fmtlist; ';
  put '        run; ';
  put '        proc sql; ';
  put '        insert into &tmpds2 select distinct fmtname,length from &tmpds3; ';
  put '      %end; ';
  put ' ';
  put '      proc sql; ';
  put '      create table &tmpds4 as ';
  put '        select a.*, b.length as MAXW ';
  put '        from &colinfo a ';
  put '        left join &tmpds2 b ';
  put '        on cats(a.format)=cats(upcase(b.fmtname)) ';
  put '        order by a.varnum; ';
  put '      data _null_; ';
  put '        set &tmpds4; ';
  put '        if not missing(maxw); ';
  put '        call symputx( ';
  put '          cats(''fmtlen'',_n_), ';
  put '          /* vars need extra padding due to JSON escaping of special chars */ ';
  put '          min(32767,ceil((max(length,maxw)+10)*1.5)) ';
  put '          ,''l'' ';
  put '        ); ';
  put '      run; ';
  put ' ';
  put '      /* configure varlenchk - as we are explicitly shortening the variables */ ';
  put '      %let optval=%sysfunc(getoption(varlenchk)); ';
  put '      options varlenchk=NOWARN; ';
  put '      data _data_(compress=char); ';
  put '        /* shorten the new vars */ ';
  put '        length ';
  put '      %do i=1 %to &numcols; ';
  put '          &&name&i $&&fmtlen&i ';
  put '      %end; ';
  put '          ; ';
  put '        /* rename on entry */ ';
  put '        set &ds(rename=( ';
  put '      %do i=1 %to &numcols; ';
  put '          &&name&i=&&newname&i ';
  put '      %end; ';
  put '        )); ';
  put '      &stmt_obs; ';
  put ' ';
  put '      drop ';
  put '      %do i=1 %to &numcols; ';
  put '        &&newname&i ';
  put '      %end; ';
  put '        ; ';
  put '      %do i=1 %to &numcols; ';
  put '        %if &&typelong&i=num %then %do; ';
  put '          &&name&i=cats(put(&&newname&i,&&fmt&i)); ';
  put '        %end; ';
  put '        %else %do; ';
  put '          &&name&i=put(&&newname&i,&&fmt&i); ';
  put '        %end; ';
  put '      %end; ';
  put '        if _error_ then do; ';
  put '          call symputx(''syscc'',1012); ';
  put '          stop; ';
  put '        end; ';
  put '      run; ';
  put '      %let fmtds=&syslast; ';
  put '      options varlenchk=&optval; ';
  put '    %end; ';
  put ' ';
  put '    proc format; /* credit yabwon for special null removal */ ';
  put '    value bart (default=40) ';
  put '    %if &missing=NULL %then %do; ';
  put '      ._ - .z = null ';
  put '    %end; ';
  put '    %else %do; ';
  put '      ._ = [quote()] ';
  put '      . = null ';
  put '      .a - .z = [quote()] ';
  put '    %end; ';
  put '      other = [best.]; ';
  put ' ';
  put '    data &tempds; ';
  put '      attrib _all_ label=''''; ';
  put '      %do i=1 %to &numcols; ';
  put '        %if &&typelong&i=char or &fmt=Y %then %do; ';
  put '          length &&name&i $&&fmtlen&i...; ';
  put '          format &&name&i $&&fmtlen&i...; ';
  put '        %end; ';
  put '      %end; ';
  put '      %if &fmt=Y %then %do; ';
  put '        set &fmtds; ';
  put '      %end; ';
  put '      %else %do; ';
  put '        set &ds; ';
  put '      %end; ';
  put '      &stmt_obs; ';
  put '      format _numeric_ bart.; ';
  put '    %do i=1 %to &numcols; ';
  put '      %if &&typelong&i=char or &fmt=Y %then %do; ';
  put '        if findc(&&name&i,''"\''!!''0A0D09000E0F010210111A''x) then do; ';
  put '          &&name&i=''"''!!trim( ';
  put '            prxchange(''s/"/\\"/'',-1,        /* double quote */ ';
  put '            prxchange(''s/\x0A/\n/'',-1,      /* new line */ ';
  put '            prxchange(''s/\x0D/\r/'',-1,      /* carriage return */ ';
  put '            prxchange(''s/\x09/\\t/'',-1,     /* tab */ ';
  put '            prxchange(''s/\x00/\\u0000/'',-1, /* NUL */ ';
  put '            prxchange(''s/\x0E/\\u000E/'',-1, /* SS  */ ';
  put '            prxchange(''s/\x0F/\\u000F/'',-1, /* SF  */ ';
  put '            prxchange(''s/\x01/\\u0001/'',-1, /* SOH */ ';
  put '            prxchange(''s/\x02/\\u0002/'',-1, /* STX */ ';
  put '            prxchange(''s/\x10/\\u0010/'',-1, /* DLE */ ';
  put '            prxchange(''s/\x11/\\u0011/'',-1, /* DC1 */ ';
  put '            prxchange(''s/\x1A/\\u001A/'',-1, /* SUB */ ';
  put '            prxchange(''s/\\/\\\\/'',-1,&&name&i) ';
  put '          )))))))))))))!!''"''; ';
  put '        end; ';
  put '        else &&name&i=quote(cats(&&name&i)); ';
  put '      %end; ';
  put '    %end; ';
  put '    run; ';
  put ' ';
  put '    filename _sjs3 temp lrecl=131068 ; ';
  put '    data _null_; ';
  put '      file _sjs3 encoding=''utf-8''; ';
  put '      if _n_=1 then put "["; ';
  put '      set &tempds; ';
  put '      if _n_>1 then put "," @; put ';
  put '      %if &action=ARR %then "[" ; %else "{" ; ';
  put '      %do i=1 %to &numcols; ';
  put '        %if &i>1 %then  "," ; ';
  put '        %if &action=OBJ %then """&&name&i"":" ; ';
  put '        "&&name&i"n /* name literal for reserved variable names */ ';
  put '      %end; ';
  put '      %if &action=ARR %then "]" ; %else "}" ; ; ';
  put ' ';
  put '    /* close out the table */ ';
  put '    data _null_; ';
  put '      file _sjs3 mod encoding=''utf-8''; ';
  put '      put '']''; ';
  put '    run; ';
  put '    data _null_; ';
  put '      infile _sjs3 lrecl=1 recfm=n; ';
  put '      file &jref mod lrecl=1 recfm=n; ';
  put '      input sourcechar $char1. @@; ';
  put '      format sourcechar hex2.; ';
  put '      put sourcechar char1. @@; ';
  put '    run; ';
  put '    filename _sjs3 clear; ';
  put '  %end; ';
  put ' ';
  put '  proc sql; ';
  put '  drop table &colinfo, &tempds; ';
  put ' ';
  put '  %if %substr(&showmeta,1,1)=Y %then %do; ';
  put '    filename _sjs4 temp lrecl=131068 encoding=''utf-8''; ';
  put '    data _null_; ';
  put '      file _sjs4; ';
  put '      length label $350; ';
  put '      put ", ""$%lowcase(%sysfunc(coalescec(&dslabel,&ds)))"":{""vars"":{"; ';
  put '      do i=1 to &numcols; ';
  put '        name=quote(trim(symget(cats(''name'',i)))); ';
  put '        format=quote(trim(symget(cats(''fmt'',i)))); ';
  put '        label=quote(prxchange(''s/\\/\\\\/'',-1,trim(symget(cats(''label'',i))))); ';
  put '        length=quote(trim(symget(cats(''length'',i)))); ';
  put '        type=quote(trim(symget(cats(''typelong'',i)))); ';
  put '        if i>1 then put "," @@; ';
  put '        put name '':{"format":'' format '',"label":'' label ';
  put '          '',"length":'' length '',"type":'' type ''}''; ';
  put '      end; ';
  put '      put ''}}''; ';
  put '    run; ';
  put '    /* send back to webout */ ';
  put '    data _null_; ';
  put '      infile _sjs4 lrecl=1 recfm=n; ';
  put '      file &jref mod lrecl=1 recfm=n; ';
  put '      input sourcechar $char1. @@; ';
  put '      format sourcechar hex2.; ';
  put '      put sourcechar char1. @@; ';
  put '    run; ';
  put '    filename _sjs4 clear; ';
  put '  %end; ';
  put '%end; ';
  put ' ';
  put '%else %if &action=CLOSE %then %do; ';
  put '  data _null_; file &jref encoding=''utf-8'' mod ; ';
  put '    put "}"; ';
  put '  run; ';
  put '%end; ';
  put '%mend mp_jsonout; ';
  put ' ';
  put '%macro mf_getuser( ';
  put ')/*/STORE SOURCE*/; ';
  put '  %local user; ';
  put ' ';
  put '  %if %symexist(_sasjs_username) %then %let user=&_sasjs_username; ';
  put '  %else %if %symexist(SYS_COMPUTE_SESSION_OWNER) %then %do; ';
  put '    %let user=&SYS_COMPUTE_SESSION_OWNER; ';
  put '  %end; ';
  put '  %else %if %symexist(_metaperson) %then %do; ';
  put '    %if %length(&_metaperson)=0 %then %let user=&sysuserid; ';
  put '    /* sometimes SAS will add @domain extension - remove for consistency */ ';
  put '    /* but be sure to quote in case of usernames with commas */ ';
  put '    %else %let user=%unquote(%scan(%quote(&_metaperson),1,@)); ';
  put '  %end; ';
  put '  %else %let user=&sysuserid; ';
  put ' ';
  put '  %quote(&user) ';
  put ' ';
  put '%mend mf_getuser; ';
  put '%macro mv_webout(action,ds,fref=_mvwtemp,dslabel=,fmt=N,stream=Y,missing=NULL ';
  put '  ,showmeta=N,maxobs=MAX,workobs=0 ';
  put '); ';
  put '%global _webin_file_count _webin_fileuri _debug _omittextlog _webin_name ';
  put '  sasjs_tables SYS_JES_JOB_URI; ';
  put '%if %index("&_debug",log) %then %let _debug=131; ';
  put ' ';
  put '%local i tempds table; ';
  put '%let action=%upcase(&action); ';
  put ' ';
  put '%if &action=FETCH %then %do; ';
  put '  %if %upcase(&_omittextlog)=FALSE or %str(&_debug) ge 131 %then %do; ';
  put '    options mprint notes mprintnest; ';
  put '  %end; ';
  put ' ';
  put '  %if not %symexist(_webin_fileuri1) %then %do; ';
  put '    %let _webin_file_count=%eval(&_webin_file_count+0); ';
  put '    %let _webin_fileuri1=&_webin_fileuri; ';
  put '    %let _webin_name1=&_webin_name; ';
  put '  %end; ';
  put ' ';
  put '  /* if the sasjs_tables param is passed, we expect param based upload */ ';
  put '  %if %length(&sasjs_tables.X)>1 %then %do; ';
  put ' ';
  put '    /* convert data from macro variables to datasets */ ';
  put '    %do i=1 %to %sysfunc(countw(&sasjs_tables)); ';
  put '      %let table=%scan(&sasjs_tables,&i,%str( )); ';
  put '      %if %symexist(sasjs&i.data0)=0 %then %let sasjs&i.data0=1; ';
  put '      data _null_; ';
  put '        file "%sysfunc(pathname(work))/&table..csv" recfm=n; ';
  put '        retain nrflg 0; ';
  put '        length line $32767; ';
  put '        do i=1 to &&sasjs&i.data0; ';
  put '          if &&sasjs&i.data0=1 then line=symget("sasjs&i.data"); ';
  put '          else line=symget(cats("sasjs&i.data",i)); ';
  put '          if i=1 and substr(line,1,7)=''%nrstr('' then do; ';
  put '            nrflg=1; ';
  put '            line=substr(line,8); ';
  put '          end; ';
  put '          if i=&&sasjs&i.data0 and nrflg=1 then do; ';
  put '            line=substr(line,1,length(line)-1); ';
  put '          end; ';
  put '          put line +(-1) @; ';
  put '        end; ';
  put '      run; ';
  put '      data _null_; ';
  put '        infile "%sysfunc(pathname(work))/&table..csv" termstr=crlf ; ';
  put '        input; ';
  put '        if _n_=1 then call symputx(''input_statement'',_infile_); ';
  put '        list; ';
  put '      data work.&table; ';
  put '        infile "%sysfunc(pathname(work))/&table..csv" firstobs=2 dsd ';
  put '          termstr=crlf; ';
  put '        input &input_statement; ';
  put '      run; ';
  put '    %end; ';
  put '  %end; ';
  put '  %else %do i=1 %to &_webin_file_count; ';
  put '    /* read in any files that are sent */ ';
  put '    /* this part needs refactoring for wide files */ ';
  put '    filename indata filesrvc "&&_webin_fileuri&i" lrecl=999999; ';
  put '    data _null_; ';
  put '      infile indata termstr=crlf lrecl=32767; ';
  put '      input; ';
  put '      if _n_=1 then call symputx(''input_statement'',_infile_); ';
  put '      %if %str(&_debug) ge 131 %then %do; ';
  put '        if _n_<20 then putlog _infile_; ';
  put '        else stop; ';
  put '      %end; ';
  put '      %else %do; ';
  put '        stop; ';
  put '      %end; ';
  put '    run; ';
  put '    data &&_webin_name&i; ';
  put '      infile indata firstobs=2 dsd termstr=crlf ; ';
  put '      input &input_statement; ';
  put '    run; ';
  put '    %let sasjs_tables=&sasjs_tables &&_webin_name&i; ';
  put '  %end; ';
  put '%end; ';
  put '%else %if &action=OPEN %then %do; ';
  put '  /* setup webout */ ';
  put '  OPTIONS NOBOMFILE; ';
  put '  %if "X&SYS_JES_JOB_URI.X"="XX" %then %do; ';
  put '    filename _webout temp lrecl=999999 mod; ';
  put '  %end; ';
  put '  %else %do; ';
  put '    filename _webout filesrvc parenturi="&SYS_JES_JOB_URI" ';
  put '      name="_webout.json" lrecl=999999 mod; ';
  put '  %end; ';
  put ' ';
  put '  /* setup temp ref */ ';
  put '  %if %upcase(&fref) ne _WEBOUT %then %do; ';
  put '    filename &fref temp lrecl=999999 permission=''A::u::rwx,A::g::rw-,A::o::---''; ';
  put '  %end; ';
  put ' ';
  put '  /* setup json */ ';
  put '  data _null_;file &fref; ';
  put '    put ''{"SYSDATE" : "'' "&SYSDATE" ''"''; ';
  put '    put '',"SYSTIME" : "'' "&SYSTIME" ''"''; ';
  put '  run; ';
  put '%end; ';
  put '%else %if &action=ARR or &action=OBJ %then %do; ';
  put '    %mp_jsonout(&action,&ds,dslabel=&dslabel,fmt=&fmt,jref=&fref ';
  put '      ,engine=DATASTEP,missing=&missing,showmeta=&showmeta,maxobs=&maxobs ';
  put '    ) ';
  put '%end; ';
  put '%else %if &action=CLOSE %then %do; ';
  put '  %if %str(&workobs) > 0 %then %do; ';
  put '    /* send back first XX records of each work table for debugging */ ';
  put '    data;run;%let tempds=%scan(&syslast,2,.); ';
  put '    ods output Members=&tempds; ';
  put '    proc datasets library=WORK memtype=data; ';
  put '    %local wtcnt;%let wtcnt=0; ';
  put '    data _null_; ';
  put '      set &tempds; ';
  put '      if not (upcase(name) =:"DATA"); /* ignore temp datasets */ ';
  put '      i+1; ';
  put '      call symputx(cats(''wt'',i),name,''l''); ';
  put '      call symputx(''wtcnt'',i,''l''); ';
  put '    data _null_; file &fref mod; put ",""WORK"":{"; ';
  put '    %do i=1 %to &wtcnt; ';
  put '      %let wt=&&wt&i; ';
  put '      data _null_; file &fref mod; ';
  put '        dsid=open("WORK.&wt",''is''); ';
  put '        nlobs=attrn(dsid,''NLOBS''); ';
  put '        nvars=attrn(dsid,''NVARS''); ';
  put '        rc=close(dsid); ';
  put '        if &i>1 then put '',''@; ';
  put '        put " ""&wt"" : {"; ';
  put '        put ''"nlobs":'' nlobs; ';
  put '        put '',"nvars":'' nvars; ';
  put '      %mp_jsonout(OBJ,&wt,jref=&fref,dslabel=first10rows,showmeta=Y ';
  put '        ,maxobs=&workobs ';
  put '      ) ';
  put '      data _null_; file &fref mod;put "}"; ';
  put '    %end; ';
  put '    data _null_; file &fref mod;put "}";run; ';
  put '  %end; ';
  put ' ';
  put '  /* close off json */ ';
  put '  data _null_;file &fref mod; ';
  put '    length SYSPROCESSNAME syserrortext syswarningtext autoexec $512; ';
  put '    put ",""_DEBUG"" : ""&_debug"" "; ';
  put '    _PROGRAM=quote(trim(resolve(symget(''_PROGRAM'')))); ';
  put '    put '',"_PROGRAM" : '' _PROGRAM ; ';
  put '    autoexec=quote(urlencode(trim(getoption(''autoexec'')))); ';
  put '    put '',"AUTOEXEC" : '' autoexec; ';
  put '    put ",""MF_GETUSER"" : ""%mf_getuser()"" "; ';
  put '    SYS_JES_JOB_URI=quote(trim(resolve(symget(''SYS_JES_JOB_URI'')))); ';
  put '    put '',"SYS_JES_JOB_URI" : '' SYS_JES_JOB_URI ; ';
  put '    put ",""SYSJOBID"" : ""&sysjobid"" "; ';
  put '    put ",""SYSCC"" : ""&syscc"" "; ';
  put '    syserrortext=cats(symget(''syserrortext'')); ';
  put '    if findc(syserrortext,''"\''!!''0A0D09000E0F010210111A''x) then do; ';
  put '      syserrortext=''"''!!trim( ';
  put '        prxchange(''s/"/\\"/'',-1,        /* double quote */ ';
  put '        prxchange(''s/\x0A/\n/'',-1,      /* new line */ ';
  put '        prxchange(''s/\x0D/\r/'',-1,      /* carriage return */ ';
  put '        prxchange(''s/\x09/\\t/'',-1,     /* tab */ ';
  put '        prxchange(''s/\x00/\\u0000/'',-1, /* NUL */ ';
  put '        prxchange(''s/\x0E/\\u000E/'',-1, /* SS  */ ';
  put '        prxchange(''s/\x0F/\\u000F/'',-1, /* SF  */ ';
  put '        prxchange(''s/\x01/\\u0001/'',-1, /* SOH */ ';
  put '        prxchange(''s/\x02/\\u0002/'',-1, /* STX */ ';
  put '        prxchange(''s/\x10/\\u0010/'',-1, /* DLE */ ';
  put '        prxchange(''s/\x11/\\u0011/'',-1, /* DC1 */ ';
  put '        prxchange(''s/\x1A/\\u001A/'',-1, /* SUB */ ';
  put '        prxchange(''s/\\/\\\\/'',-1,syserrortext) ';
  put '      )))))))))))))!!''"''; ';
  put '    end; ';
  put '    else syserrortext=cats(''"'',syserrortext,''"''); ';
  put '    put '',"SYSERRORTEXT" : '' syserrortext; ';
  put '    put ",""SYSHOSTNAME"" : ""&syshostname"" "; ';
  put '    put ",""SYSPROCESSID"" : ""&SYSPROCESSID"" "; ';
  put '    put ",""SYSPROCESSMODE"" : ""&SYSPROCESSMODE"" "; ';
  put '    SYSPROCESSNAME=quote(urlencode(cats(SYSPROCESSNAME))); ';
  put '    put ",""SYSPROCESSNAME"" : " SYSPROCESSNAME; ';
  put '    put ",""SYSJOBID"" : ""&sysjobid"" "; ';
  put '    put ",""SYSSCPL"" : ""&sysscpl"" "; ';
  put '    put ",""SYSSITE"" : ""&syssite"" "; ';
  put '    put ",""SYSUSERID"" : ""&sysuserid"" "; ';
  put '    sysvlong=quote(trim(symget(''sysvlong''))); ';
  put '    put '',"SYSVLONG" : '' sysvlong; ';
  put '    syswarningtext=cats(symget(''syswarningtext'')); ';
  put '    if findc(syswarningtext,''"\''!!''0A0D09000E0F010210111A''x) then do; ';
  put '      syswarningtext=''"''!!trim( ';
  put '        prxchange(''s/"/\\"/'',-1,        /* double quote */ ';
  put '        prxchange(''s/\x0A/\n/'',-1,      /* new line */ ';
  put '        prxchange(''s/\x0D/\r/'',-1,      /* carriage return */ ';
  put '        prxchange(''s/\x09/\\t/'',-1,     /* tab */ ';
  put '        prxchange(''s/\x00/\\u0000/'',-1, /* NUL */ ';
  put '        prxchange(''s/\x0E/\\u000E/'',-1, /* SS  */ ';
  put '        prxchange(''s/\x0F/\\u000F/'',-1, /* SF  */ ';
  put '        prxchange(''s/\x01/\\u0001/'',-1, /* SOH */ ';
  put '        prxchange(''s/\x02/\\u0002/'',-1, /* STX */ ';
  put '        prxchange(''s/\x10/\\u0010/'',-1, /* DLE */ ';
  put '        prxchange(''s/\x11/\\u0011/'',-1, /* DC1 */ ';
  put '        prxchange(''s/\x1A/\\u001A/'',-1, /* SUB */ ';
  put '        prxchange(''s/\\/\\\\/'',-1,syswarningtext) ';
  put '      )))))))))))))!!''"''; ';
  put '    end; ';
  put '    else syswarningtext=cats(''"'',syswarningtext,''"''); ';
  put '    put '',"SYSWARNINGTEXT" : '' syswarningtext; ';
  put '    put '',"END_DTTM" : "'' "%sysfunc(datetime(),E8601DT26.6)" ''" ''; ';
  put '    length memsize $32; ';
  put '    memsize="%sysfunc(INPUTN(%sysfunc(getoption(memsize)), best.),sizekmg.)"; ';
  put '    memsize=quote(cats(memsize)); ';
  put '    put '',"MEMSIZE" : '' memsize; ';
  put '    put "}"; ';
  put ' ';
  put '  %if %upcase(&fref) ne _WEBOUT and &stream=Y %then %do; ';
  put '    data _null_; rc=fcopy("&fref","_webout");run; ';
  put '  %end; ';
  put ' ';
  put '%end; ';
  put ' ';
  put '%mend mv_webout; ';
/* WEBOUT END */
  put '/* if calling viya service with _job param, _program will conflict */';
  put '/* so it is provided by SASjs instead as __program */';
  put '%global __program _program;';
  put '%let _program=%sysfunc(coalescec(&__program,&_program));';
  put ' ';
  put '%macro webout(action,ds,dslabel=,fmt=,missing=NULL,showmeta=NO';
  put '    ,maxobs=MAX';
  put ');';
  put '  %mv_webout(&action,ds=&ds,dslabel=&dslabel,fmt=&fmt,missing=&missing';
  put '    ,showmeta=&showmeta,maxobs=&maxobs';
  put '  )';
  put '%mend;';
run;

/* insert the code, escaping double quotes and carriage returns */
%&dbg.put &sysmacroname: Creating final input file;
%local x fref freflist;
%let freflist= &adapter &precode &code ;
%do x=1 %to %sysfunc(countw(&freflist));
  %let fref=%scan(&freflist,&x);
  %&dbg.put &sysmacroname: adding &fref fileref;
  data _null_;
    length filein 8 fileid 8;
    filein = fopen("&fref","I",1,"B");
    fileid = fopen("&fname3","A",1,"B");
    rec = "20"x;
    do while(fread(filein)=0);
      rc = fget(filein,rec,1);
      if rec='"' then do;  /* DOUBLE QUOTE */
        rc =fput(fileid,'\');rc =fwrite(fileid);
        rc =fput(fileid,'"');rc =fwrite(fileid);
      end;
      else if rec='0A'x then do; /* LF */
        rc =fput(fileid,'\');rc =fwrite(fileid);
        rc =fput(fileid,'n');rc =fwrite(fileid);
      end;
      else if rec='0D'x then do; /* CR */
        rc =fput(fileid,'\');rc =fwrite(fileid);
        rc =fput(fileid,'r');rc =fwrite(fileid);
      end;
      else if rec='09'x then do; /* TAB */
        rc =fput(fileid,'\');rc =fwrite(fileid);
        rc =fput(fileid,'t');rc =fwrite(fileid);
      end;
      else if rec='5C'x then do; /* BACKSLASH */
        rc =fput(fileid,'\');rc =fwrite(fileid);
        rc =fput(fileid,'\');rc =fwrite(fileid);
      end;
      else if rec='01'x then do; /* Unprintable */
        rc =fput(fileid,'\');rc =fwrite(fileid);
        rc =fput(fileid,'u');rc =fwrite(fileid);
        rc =fput(fileid,'0');rc =fwrite(fileid);
        rc =fput(fileid,'0');rc =fwrite(fileid);
        rc =fput(fileid,'0');rc =fwrite(fileid);
        rc =fput(fileid,'1');rc =fwrite(fileid);
      end;
      else if rec='07'x then do; /* Bell Char */
        rc =fput(fileid,'\');rc =fwrite(fileid);
        rc =fput(fileid,'u');rc =fwrite(fileid);
        rc =fput(fileid,'0');rc =fwrite(fileid);
        rc =fput(fileid,'0');rc =fwrite(fileid);
        rc =fput(fileid,'0');rc =fwrite(fileid);
        rc =fput(fileid,'7');rc =fwrite(fileid);
      end;
      else if rec='1B'x then do; /* escape char */
        rc =fput(fileid,'\');rc =fwrite(fileid);
        rc =fput(fileid,'u');rc =fwrite(fileid);
        rc =fput(fileid,'0');rc =fwrite(fileid);
        rc =fput(fileid,'0');rc =fwrite(fileid);
        rc =fput(fileid,'1');rc =fwrite(fileid);
        rc =fput(fileid,'B');rc =fwrite(fileid);
      end;
      else do;
        rc =fput(fileid,rec);
        rc =fwrite(fileid);
      end;
    end;
    rc=fclose(filein);
    rc=fclose(fileid);
  run;
%end;

/* finish off the body of the code file loaded to JES */
data _null_;
  file &fname3 mod TERMSTR=' ';
  put '"}';
run;

%if &mdebug=1 and &SYS_PROCHTTP_STATUS_CODE ne 201 %then %do;
  %put &sysmacroname: input about to be POSTed;
  data _null_;infile &fname3;input;putlog _infile_;run;
%end;

%&dbg.put &sysmacroname: Creating the actual service!;
%local fname4;
%let fname4=%mf_getuniquefileref();
proc http method='POST'
    in=&fname3
    out=&fname4
    &oauth_bearer
    url="&base_uri/jobDefinitions/definitions?parentFolderUri=&parentFolderUri";
    headers 'Content-Type'='application/vnd.sas.job.definition+json'
  %if &grant_type=authorization_code %then %do;
            "Authorization"="Bearer &&&access_token_var"
  %end;
            "Accept"="application/vnd.sas.job.definition+json";
%if &mdebug=1 %then %do;
    debug level = 3;
%end;
run;
%if &mdebug=1 and &SYS_PROCHTTP_STATUS_CODE ne 201 %then %do;
  %put &sysmacroname: output from POSTing job definition;
  data _null_;infile &fname4;input;putlog _infile_;run;
%end;
%mp_abort(iftrue=(&SYS_PROCHTTP_STATUS_CODE ne 201)
  ,mac=&sysmacroname
  ,msg=%str(&SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE)
)

/* get the url so we can give a helpful log message */
%local url;
data _null_;
  if symexist('_baseurl') then do;
    url=symget('_baseurl');
    if subpad(url,length(url)-9,9)='SASStudio'
      then url=substr(url,1,length(url)-11);
    else url="&systcpiphostname";
  end;
  else url="&systcpiphostname";
  call symputx('url',url);
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
  filename &fname4 clear;
  filename &adapter clear;
  libname &libref1 clear;
%end;

%put &sysmacroname: Job &name successfully created in &path;
%put &sysmacroname:;
%put &sysmacroname: Check it out here:;
%put &sysmacroname:;%put;
%put    &url/SASJobExecution?_PROGRAM=&path/&name;%put;
%put &sysmacroname:;
%put &sysmacroname:;

%mend mv_createwebservice;
