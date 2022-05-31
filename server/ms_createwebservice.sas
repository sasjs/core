/**
  @file ms_createwebservice.sas
  @brief Create a Web-Ready Stored Program
  @details This macro creates a Stored Program along with the necessary precode
  to enable the %webout() macro

  Usage:
  <code>
    %* compile macros ;
    filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
    %inc mc;

    %* parmcards lets us write to a text file from open code ;
    filename ft15f001 temp;
    parmcards4;
        %webout(FETCH)
        %* do some sas, any inputs are now already WORK tables;
        data example1 example2;
          set sashelp.class;
        run;
        %* send data back;
        %webout(OPEN)
        %webout(ARR,example1) * Array format, fast, suitable for large tables ;
        %webout(OBJ,example2) * Object format, easier to work with ;
        %webout(CLOSE)
    ;;;;
    %ms_createwebservice(path=/Public/app/common,name=appInit,code=ft15f001)

  </code>

  For more examples of using these web services with the SASjs Adapter, see:
  https://github.com/sasjs/adapter#readme

  @param [in] path= (0) The full SASjs Drive path in which to create the service
  @param [in] name= Stored Program name
  @param [in] desc= The description of the service (not implemented yet)
  @param [in] precode= Space separated list of filerefs, pointing to the code
    that needs to be attached to the beginning of the service (optional)
  @param [in] code= (ft15f001) Space seperated fileref(s) of the actual code to
    be added
  @param [in] mDebug= (0) set to 1 to show debug messages in the log

  <h4> SAS Macros </h4>
  @li ms_createfile.sas
  @li mf_getuser.sas
  @li mf_getuniquename.sas
  @li mf_getuniquefileref.sas
  @li mp_abort.sas

  <h4> Related Files </h4>
  @li ms_createwebservice.test.sas

  @version 9.2
  @author Allan Bowe

**/

%macro ms_createwebservice(path=0
    ,name=initService
    ,precode=
    ,code=ft15f001
    ,desc=Not currently used
    ,mDebug=0
)/*/STORE SOURCE*/;

%local dbg;
%if &mdebug=1 %then %do;
  %put &sysmacroname entry vars:;
  %put _local_;
%end;
%else %let dbg=*;

%mp_abort(iftrue=(&syscc ge 4 )
  ,mac=ms_createwebservice
  ,msg=%str(syscc=&syscc on macro entry)
)
%mp_abort(iftrue=("&path"="0")
  ,mac=ms_createwebservice
  ,msg=%str(Path not provided)
)

/* remove any trailing slash */
%if "%substr(&path,%length(&path),1)" = "/" %then
  %let path=%substr(&path,1,%length(&path)-1);

/**
  * Add webout macro
  * These put statements are auto generated - to change the macro, change the
  * source (ms_webout) and run `build.py`
  */
%local sasjsref;
%let sasjsref=%mf_getuniquefileref();
data _null_;
  file &sasjsref termstr=crlf lrecl=512;
  put "/* Created on %sysfunc(datetime(),datetime19.) by %mf_getuser() */";
/* WEBOUT BEGIN */
  put ' ';
  put '%macro mp_jsonout(action,ds,jref=_webout,dslabel=,fmt=Y ';
  put '  ,engine=DATASTEP ';
  put '  ,missing=NULL ';
  put '  ,showmeta=NO ';
  put ')/*/STORE SOURCE*/; ';
  put '%local tempds colinfo fmtds i numcols; ';
  put '%let numcols=0; ';
  put ' ';
  put '%if &action=OPEN %then %do; ';
  put '  options nobomfile; ';
  put '  data _null_;file &jref encoding=''utf-8'' lrecl=200; ';
  put '    put ''{"PROCESSED_DTTM" : "'' "%sysfunc(datetime(),E8601DT26.6)" ''"''; ';
  put '  run; ';
  put '%end; ';
  put '%else %if (&action=ARR or &action=OBJ) %then %do; ';
  put '  options validvarname=upcase; ';
  put '  data _null_; file &jref encoding=''utf-8'' mod; ';
  put '    put ", ""%lowcase(%sysfunc(coalescec(&dslabel,&ds)))"":"; ';
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
  put '  data _null_; ';
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
  put '      newlen=max(formatl,length); ';
  put '    end; ';
  put '    else do; ';
  put '      typelong=''num''; ';
  put '      if format='''' then fmt=''best.''; ';
  put '      else if formatl=0 then fmt=cats(format,''.''); ';
  put '      else if formatd=0 then fmt=cats(format,formatl,''.''); ';
  put '      else fmt=cats(format,formatl,''.'',formatd); ';
  put '      /* needs to be wide, for datetimes etc */ ';
  put '      newlen=max(length,formatl,24); ';
  put '    end; ';
  put '    /* 32 char unique name */ ';
  put '    newname=''sasjs''!!substr(cats(put(md5(name),$hex32.)),1,27); ';
  put ' ';
  put '    call symputx(cats(''name'',_n_),name,''l''); ';
  put '    call symputx(cats(''newname'',_n_),newname,''l''); ';
  put '    call symputx(cats(''len'',_n_),newlen,''l''); ';
  put '    call symputx(cats(''length'',_n_),length,''l''); ';
  put '    call symputx(cats(''fmt'',_n_),fmt,''l''); ';
  put '    call symputx(cats(''type'',_n_),type,''l''); ';
  put '    call symputx(cats(''typelong'',_n_),typelong,''l''); ';
  put '    call symputx(cats(''label'',_n_),coalescec(label,name),''l''); ';
  put '  run; ';
  put ' ';
  put '  %let tempds=%substr(_%sysfunc(compress(%sysfunc(uuidgen()),-)),1,32); ';
  put ' ';
  put '  %if &engine=PROCJSON %then %do; ';
  put '    %if &missing=STRING %then %do; ';
  put '      %put &sysmacroname: Special Missings not supported in proc json.; ';
  put '      %put &sysmacroname: Switching to DATASTEP engine; ';
  put '      %goto datastep; ';
  put '    %end; ';
  put '    data &tempds;set &ds; ';
  put '    %if &fmt=N %then format _numeric_ best32.;; ';
  put '    /* PRETTY is necessary to avoid line truncation in large files */ ';
  put '    proc json out=&jref pretty ';
  put '        %if &action=ARR %then nokeys ; ';
  put '        ;export &tempds / nosastags fmtnumeric; ';
  put '    run; ';
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
  put '      data _data_; ';
  put '        /* rename on entry */ ';
  put '        set &ds(rename=( ';
  put '      %do i=1 %to &numcols; ';
  put '        &&name&i=&&newname&i ';
  put '      %end; ';
  put '        )); ';
  put '      %do i=1 %to &numcols; ';
  put '        length &&name&i $&&len&i; ';
  put '        %if &&typelong&i=num %then %do; ';
  put '          &&name&i=left(put(&&newname&i,&&fmt&i)); ';
  put '        %end; ';
  put '        %else %do; ';
  put '          &&name&i=put(&&newname&i,&&fmt&i); ';
  put '        %end; ';
  put '        drop &&newname&i; ';
  put '      %end; ';
  put '        if _error_ then call symputx(''syscc'',1012); ';
  put '      run; ';
  put '      %let fmtds=&syslast; ';
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
  put '          length &&name&i $32767; ';
  put '          format &&name&i $32767.; ';
  put '        %end; ';
  put '      %end; ';
  put '      %if &fmt=Y %then %do; ';
  put '        set &fmtds; ';
  put '      %end; ';
  put '      %else %do; ';
  put '        set &ds; ';
  put '      %end; ';
  put '      format _numeric_ bart.; ';
  put '    %do i=1 %to &numcols; ';
  put '      %if &&typelong&i=char or &fmt=Y %then %do; ';
  put '        if findc(&&name&i,''"\''!!''0A0D09000E0F01021011''x) then do; ';
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
  put '            prxchange(''s/\\/\\\\/'',-1,&&name&i) ';
  put '          ))))))))))))!!''"''; ';
  put '        end; ';
  put '        else &&name&i=quote(cats(&&name&i)); ';
  put '      %end; ';
  put '    %end; ';
  put '    run; ';
  put ' ';
  put '    /* write to temp loc to avoid _webout truncation ';
  put '      - https://support.sas.com/kb/49/325.html */ ';
  put '    filename _sjs temp lrecl=131068 encoding=''utf-8''; ';
  put '    data _null_; file _sjs lrecl=131068 encoding=''utf-8'' mod ; ';
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
  put '    /* now write the long strings to _webout 1 byte at a time */ ';
  put '    data _null_; ';
  put '      length filein 8 fileid 8; ';
  put '      filein=fopen("_sjs",''I'',1,''B''); ';
  put '      fileid=fopen("&jref",''A'',1,''B''); ';
  put '      rec=''20''x; ';
  put '      do while(fread(filein)=0); ';
  put '        rc=fget(filein,rec,1); ';
  put '        rc=fput(fileid, rec); ';
  put '        rc=fwrite(fileid); ';
  put '      end; ';
  put '      /* close out the table */ ';
  put '      rc=fput(fileid, "]"); ';
  put '      rc=fwrite(fileid); ';
  put '      rc=fclose(filein); ';
  put '      rc=fclose(fileid); ';
  put '    run; ';
  put '    filename _sjs clear; ';
  put '  %end; ';
  put ' ';
  put '  proc sql; ';
  put '  drop table &colinfo, &tempds; ';
  put ' ';
  put '  %if &showmeta=YES %then %do; ';
  put '    data _null_; file &jref encoding=''utf-8'' mod; ';
  put '      put ", ""$%lowcase(%sysfunc(coalescec(&dslabel,&ds)))"":{""vars"":{"; ';
  put '      do i=1 to &numcols; ';
  put '        name=quote(trim(symget(cats(''name'',i)))); ';
  put '        format=quote(trim(symget(cats(''fmt'',i)))); ';
  put '        label=quote(trim(symget(cats(''label'',i)))); ';
  put '        length=quote(trim(symget(cats(''length'',i)))); ';
  put '        type=quote(trim(symget(cats(''typelong'',i)))); ';
  put '        if i>1 then put "," @@; ';
  put '        put name '':{"format":'' format '',"label":'' label ';
  put '          '',"length":'' length '',"type":'' type ''}''; ';
  put '      end; ';
  put '      put ''}}''; ';
  put '    run; ';
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
  put '%macro mf_getuser(type=META ';
  put ')/*/STORE SOURCE*/; ';
  put '  %local user metavar; ';
  put '  %if &type=OS %then %let metavar=_secureusername; ';
  put '  %else %let metavar=_metaperson; ';
  put ' ';
  put '  %if %symexist(SYS_COMPUTE_SESSION_OWNER) %then %let user=&SYS_COMPUTE_SESSION_OWNER; ';
  put '  %else %if %symexist(&metavar) %then %do; ';
  put '    %if %length(&&&metavar)=0 %then %let user=&sysuserid; ';
  put '    /* sometimes SAS will add @domain extension - remove for consistency */ ';
  put '    /* but be sure to quote in case of usernames with commas */ ';
  put '    %else %let user=%unquote(%scan(%quote(&&&metavar),1,@)); ';
  put '  %end; ';
  put '  %else %let user=&sysuserid; ';
  put ' ';
  put '  %quote(&user) ';
  put ' ';
  put '%mend mf_getuser; ';
  put ' ';
  put '%macro ms_webout(action,ds,dslabel=,fref=_webout,fmt=Y,missing=NULL ';
  put '  ,showmeta=NO ';
  put '); ';
  put '%global _webin_file_count _webin_fileref1 _webin_name1 _program _debug ';
  put '  sasjs_tables; ';
  put ' ';
  put '%local i tempds; ';
  put '%let action=%upcase(&action); ';
  put ' ';
  put '%if &action=FETCH %then %do; ';
  put '  %if %str(&_debug) ge 131 %then %do; ';
  put '    options mprint notes mprintnest; ';
  put '  %end; ';
  put '  %let _webin_file_count=%eval(&_webin_file_count+0); ';
  put '  /* now read in the data */ ';
  put '  %do i=1 %to &_webin_file_count; ';
  put '    %if &_webin_file_count=1 %then %do; ';
  put '      %let _webin_fileref1=&_webin_fileref; ';
  put '      %let _webin_name1=&_webin_name; ';
  put '    %end; ';
  put '    data _null_; ';
  put '      infile &&_webin_fileref&i termstr=crlf lrecl=32767; ';
  put '      input; ';
  put '      call symputx(''input_statement'',_infile_); ';
  put '      putlog "&&_webin_name&i input statement: "  _infile_; ';
  put '      stop; ';
  put '    data &&_webin_name&i; ';
  put '      infile &&_webin_fileref&i firstobs=2 dsd termstr=crlf encoding=''utf-8'' ';
  put '        lrecl=32767; ';
  put '      input &input_statement; ';
  put '      %if %str(&_debug) ge 131 %then %do; ';
  put '        if _n_<20 then putlog _infile_; ';
  put '      %end; ';
  put '    run; ';
  put '    %let sasjs_tables=&sasjs_tables &&_webin_name&i; ';
  put '  %end; ';
  put '%end; ';
  put ' ';
  put '%else %if &action=OPEN %then %do; ';
  put '  /* fix encoding and ensure enough lrecl */ ';
  put '  OPTIONS NOBOMFILE lrecl=32767; ';
  put ' ';
  put '  /* set the header */ ';
  put '  %mfs_httpheader(Content-type,application/json) ';
  put ' ';
  put '  /* setup json.  */ ';
  put '  data _null_;file &fref encoding=''utf-8'' termstr=lf ; ';
  put '    put ''{"SYSDATE" : "'' "&SYSDATE" ''"''; ';
  put '    put '',"SYSTIME" : "'' "&SYSTIME" ''"''; ';
  put '  run; ';
  put ' ';
  put '%end; ';
  put ' ';
  put '%else %if &action=ARR or &action=OBJ %then %do; ';
  put '  %if "%substr(&sysver,1,1)"="4" or "%substr(&sysver,1,1)"="5" %then %do; ';
  put '    /* functions in formats unsupported */ ';
  put '    %put &sysmacroname: forcing missing back to NULL as feature not supported; ';
  put '    %let missing=NULL; ';
  put '  %end; ';
  put '  %mp_jsonout(&action,&ds,dslabel=&dslabel,fmt=&fmt,jref=&fref ';
  put '    ,engine=DATASTEP,missing=&missing,showmeta=&showmeta ';
  put '  ) ';
  put '%end; ';
  put '%else %if &action=CLOSE %then %do; ';
  put '  %if %str(&_debug) ge 131 %then %do; ';
  put '    /* if debug mode, send back first 10 records of each work table also */ ';
  put '    options obs=10; ';
  put '    data;run;%let tempds=%scan(&syslast,2,.); ';
  put '    ods output Members=&tempds; ';
  put '    proc datasets library=WORK memtype=data; ';
  put '    %local wtcnt;%let wtcnt=0; ';
  put '    data _null_; ';
  put '      set &tempds; ';
  put '      if not (upcase(name) =:"DATA"); /* ignore temp datasets */ ';
  put '      if not (upcase(name)=:"_DATA_"); ';
  put '      i+1; ';
  put '      call symputx(cats(''wt'',i),name,''l''); ';
  put '      call symputx(''wtcnt'',i,''l''); ';
  put '    data _null_; file &fref mod encoding=''utf-8'' termstr=lf; ';
  put '      put ",""WORK"":{"; ';
  put '    %do i=1 %to &wtcnt; ';
  put '      %let wt=&&wt&i; ';
  put '      data _null_; file &fref mod encoding=''utf-8'' termstr=lf; ';
  put '        dsid=open("WORK.&wt",''is''); ';
  put '        nlobs=attrn(dsid,''NLOBS''); ';
  put '        nvars=attrn(dsid,''NVARS''); ';
  put '        rc=close(dsid); ';
  put '        if &i>1 then put '',''@; ';
  put '        put " ""&wt"" : {"; ';
  put '        put ''"nlobs":'' nlobs; ';
  put '        put '',"nvars":'' nvars; ';
  put '      %mp_jsonout(OBJ,&wt,jref=&fref,dslabel=first10rows,showmeta=YES) ';
  put '      data _null_; file &fref mod encoding=''utf-8'' termstr=lf; ';
  put '        put "}"; ';
  put '    %end; ';
  put '    data _null_; file &fref mod encoding=''utf-8'' termstr=lf; ';
  put '      put "}"; ';
  put '    run; ';
  put '  %end; ';
  put '  /* close off json */ ';
  put '  data _null_;file &fref mod encoding=''utf-8'' termstr=lf lrecl=32767; ';
  put '    _PROGRAM=quote(trim(resolve(symget(''_PROGRAM'')))); ';
  put '    put ",""SYSUSERID"" : ""&sysuserid"" "; ';
  put '    put ",""MF_GETUSER"" : ""%mf_getuser()"" "; ';
  put '    put ",""_DEBUG"" : ""&_debug"" "; ';
  put '    put '',"_PROGRAM" : '' _PROGRAM ; ';
  put '    put ",""SYSCC"" : ""&syscc"" "; ';
  put '    syserrortext=quote(cats(symget(''SYSERRORTEXT''))); ';
  put '    put '',"SYSERRORTEXT" : '' syserrortext; ';
  put '    SYSHOSTINFOLONG=quote(trim(symget(''SYSHOSTINFOLONG''))); ';
  put '    put '',"SYSHOSTINFOLONG" : '' SYSHOSTINFOLONG; ';
  put '    put ",""SYSHOSTNAME"" : ""&syshostname"" "; ';
  put '    put ",""SYSPROCESSID"" : ""&SYSPROCESSID"" "; ';
  put '    put ",""SYSPROCESSMODE"" : ""&SYSPROCESSMODE"" "; ';
  put '    length SYSPROCESSNAME $512; ';
  put '    SYSPROCESSNAME=quote(urlencode(cats(SYSPROCESSNAME))); ';
  put '    put ",""SYSPROCESSNAME"" : " SYSPROCESSNAME; ';
  put '    put ",""SYSJOBID"" : ""&sysjobid"" "; ';
  put '    put ",""SYSSCPL"" : ""&sysscpl"" "; ';
  put '    put ",""SYSSITE"" : ""&syssite"" "; ';
  put '    put ",""SYSTCPIPHOSTNAME"" : ""&SYSTCPIPHOSTNAME"" "; ';
  put '    sysvlong=quote(trim(symget(''sysvlong''))); ';
  put '    put '',"SYSVLONG" : '' sysvlong; ';
  put '    syswarningtext=quote(cats(symget(''SYSWARNINGTEXT''))); ';
  put '    put '',"SYSWARNINGTEXT" : '' syswarningtext; ';
  put '    put '',"END_DTTM" : "'' "%sysfunc(datetime(),E8601DT26.6)" ''" ''; ';
  put '    length autoexec $512; ';
  put '    autoexec=quote(urlencode(trim(getoption(''autoexec'')))); ';
  put '    put '',"AUTOEXEC" : '' autoexec; ';
  put '    length memsize $32; ';
  put '    memsize="%sysfunc(INPUTN(%sysfunc(getoption(memsize)), best.),sizekmg.)"; ';
  put '    memsize=quote(cats(memsize)); ';
  put '    put '',"MEMSIZE" : '' memsize; ';
  put '    put "}" @; ';
  put '  run; ';
  put '%end; ';
  put ' ';
  put '%mend ms_webout; ';
  put ' ';
  put '%macro mfs_httpheader(header_name ';
  put '  ,header_value ';
  put ')/*/STORE SOURCE*/; ';
  put '%global sasjs_stpsrv_header_loc; ';
  put '%local fref fid i; ';
  put ' ';
  put '%if %sysfunc(filename(fref,&sasjs_stpsrv_header_loc)) ne 0 %then %do; ';
  put '  %put &=fref &=sasjs_stpsrv_header_loc; ';
  put '  %put %str(ERR)OR: %sysfunc(sysmsg()); ';
  put '  %return; ';
  put '%end; ';
  put ' ';
  put '%let fid=%sysfunc(fopen(&fref,A)); ';
  put ' ';
  put '%if &fid=0 %then %do; ';
  put '  %put %str(ERR)OR: %sysfunc(sysmsg()); ';
  put '  %return; ';
  put '%end; ';
  put ' ';
  put '%let rc=%sysfunc(fput(&fid,%str(&header_name): %str(&header_value))); ';
  put '%let rc=%sysfunc(fwrite(&fid)); ';
  put ' ';
  put '%let rc=%sysfunc(fclose(&fid)); ';
  put '%let rc=%sysfunc(filename(&fref)); ';
  put ' ';
  put '%mend mfs_httpheader; ';
/* WEBOUT END */
  put '%macro webout(action,ds,dslabel=,fmt=,missing=NULL,showmeta=NO);';
  put '  %ms_webout(&action,ds=&ds,dslabel=&dslabel,fmt=&fmt,missing=&missing';
  put '    ,showmeta=&showmeta';
  put '  )';
  put '%mend;';
run;

/* add precode and code */
%local x fref freflist;
%let freflist=&precode &code ;
%do x=1 %to %sysfunc(countw(&freflist));
  %let fref=%scan(&freflist,&x);
  %put &sysmacroname: adding &fref;
  data _null_;
    file &sasjsref lrecl=3000 termstr=crlf mod;
    infile &fref lrecl=3000;
    input;
    put _infile_;
  run;
%end;

/* create the web service */
%ms_createfile(&path/&name..sas, inref=&sasjsref, mdebug=&mdebug)

%put ;%put ;%put ;%put ;%put ;%put ;
%put &sysmacroname: STP &name successfully created in &path;
%put ;%put ;%put ;
%put Check it out here:;
%put ;%put ;%put ;
%put &_sasjs_apiserverurl.&_sasjs_apipath?_PROGRAM=&path/&name;
%put ;%put ;%put ;%put ;%put ;%put ;

%mend ms_createwebservice;
