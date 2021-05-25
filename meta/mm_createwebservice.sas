/**
  @file mm_createwebservice.sas
  @brief Create a Web Ready Stored Process
  @details This macro creates a Type 2 Stored Process with the mm_webout macro
    included as pre-code.
Usage:

    %* compile macros ;
    filename mc url "https://raw.githubusercontent.com/sasjs/core/main/all.sas";
    %inc mc;

    %* parmcards lets us write to a text file from open code ;
    filename ft15f001 temp;
    parmcards4;
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
    %mm_createwebservice(path=/Public/app/common,name=appInit)

  <h4> SAS Macros </h4>
  @li mm_createstp.sas
  @li mf_getuser.sas
  @li mm_createfolder.sas
  @li mm_deletestp.sas

  @param path= The full path (in SAS Metadata) where the service will be created
  @param name= Stored Process name.  Avoid spaces - testing has shown that
    the check to avoid creating multiple STPs in the same folder with the same
    name does not work when the name contains spaces.
  @param desc= The description of the service (optional)
  @param precode= Space separated list of filerefs, pointing to the code that
    needs to be attached to the beginning of the service (optional)
  @param code= Space seperated fileref(s) of the actual code to be added
  @param server= The server which will run the STP.  Server name or uri is fine.
  @param mDebug= set to 1 to show debug messages in the log
  @param replace= select YES to replace any existing service in that location
  @param adapter= the macro uses the sasjs adapter by default.  To use another
    adapter, add a (different) fileref here.

  @version 9.2
  @author Allan Bowe

**/

%macro mm_createwebservice(path=
    ,name=initService
    ,precode=
    ,code=
    ,desc=This stp was created automagically by the mm_createwebservice macro
    ,mDebug=0
    ,server=SASApp
    ,replace=NO
    ,adapter=sasjs
)/*/STORE SOURCE*/;

%if &syscc ge 4 %then %do;
  %put &=syscc - &sysmacroname will not execute in this state;
  %return;
%end;

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing mm_createwebservice.sas;
%&mD.put _local_;

* remove any trailing slash ;
%if "%substr(&path,%length(&path),1)" = "/" %then
  %let path=%substr(&path,1,%length(&path)-1);

/**
  * Add webout macro
  * These put statements are auto generated - to change the macro, change the
  * source (mm_webout) and run `build.py`
  */
filename sasjs temp;
data _null_;
  file sasjs lrecl=3000 ;
  put "/* Created on %sysfunc(datetime(),datetime19.) by %mf_getuser() */";
/* WEBOUT BEGIN */
  put ' ';
  put '%macro mp_jsonout(action,ds,jref=_webout,dslabel=,fmt=Y,engine=DATASTEP,dbg=0 ';
  put ')/*/STORE SOURCE*/; ';
  put '%put output location=&jref; ';
  put '%if &action=OPEN %then %do; ';
  put '  options nobomfile; ';
  put '  data _null_;file &jref encoding=''utf-8''; ';
  put '    put ''{"START_DTTM" : "'' "%sysfunc(datetime(),datetime20.3)" ''"''; ';
  put '  run; ';
  put '%end; ';
  put '%else %if (&action=ARR or &action=OBJ) %then %do; ';
  put '  options validvarname=upcase; ';
  put '  data _null_;file &jref mod encoding=''utf-8''; ';
  put '    put ", ""%lowcase(%sysfunc(coalescec(&dslabel,&ds)))"":"; ';
  put ' ';
  put '  %if &engine=PROCJSON %then %do; ';
  put '    data;run;%let tempds=&syslast; ';
  put '    proc sql;drop table &tempds; ';
  put '    data &tempds /view=&tempds;set &ds; ';
  put '    %if &fmt=N %then format _numeric_ best32.;; ';
  put '    proc json out=&jref pretty ';
  put '        %if &action=ARR %then nokeys ; ';
  put '        ;export &tempds / nosastags fmtnumeric; ';
  put '    run; ';
  put '    proc sql;drop view &tempds; ';
  put '  %end; ';
  put '  %else %if &engine=DATASTEP %then %do; ';
  put '    %local cols i tempds; ';
  put '    %let cols=0; ';
  put '    %if %sysfunc(exist(&ds)) ne 1 & %sysfunc(exist(&ds,VIEW)) ne 1 %then %do; ';
  put '      %put &sysmacroname:  &ds NOT FOUND!!!; ';
  put '      %return; ';
  put '    %end; ';
  put '    %if &fmt=Y %then %do; ';
  put '      %put converting every variable to a formatted variable; ';
  put '      /* see mp_ds2fmtds.sas for source */ ';
  put '      proc contents noprint data=&ds ';
  put '        out=_data_(keep=name type length format formatl formatd varnum); ';
  put '      run; ';
  put '      proc sort; ';
  put '        by varnum; ';
  put '      run; ';
  put '      %local fmtds; ';
  put '      %let fmtds=%scan(&syslast,2,.); ';
  put '      /* prepare formats and varnames */ ';
  put '      data _null_; ';
  put '        set &fmtds end=last; ';
  put '        name=upcase(name); ';
  put '        /* fix formats */ ';
  put '        if type=2 or type=6 then do; ';
  put '          length fmt $49.; ';
  put '          if format='''' then fmt=cats(''$'',length,''.''); ';
  put '          else if formatl=0 then fmt=cats(format,''.''); ';
  put '          else fmt=cats(format,formatl,''.''); ';
  put '          newlen=max(formatl,length); ';
  put '        end; ';
  put '        else do; ';
  put '          if format='''' then fmt=''best.''; ';
  put '          else if formatl=0 then fmt=cats(format,''.''); ';
  put '          else if formatd=0 then fmt=cats(format,formatl,''.''); ';
  put '          else fmt=cats(format,formatl,''.'',formatd); ';
  put '          /* needs to be wide, for datetimes etc */ ';
  put '          newlen=max(length,formatl,24); ';
  put '        end; ';
  put '        /* 32 char unique name */ ';
  put '        newname=''sasjs''!!substr(cats(put(md5(name),$hex32.)),1,27); ';
  put ' ';
  put '        call symputx(cats(''name'',_n_),name,''l''); ';
  put '        call symputx(cats(''newname'',_n_),newname,''l''); ';
  put '        call symputx(cats(''len'',_n_),newlen,''l''); ';
  put '        call symputx(cats(''fmt'',_n_),fmt,''l''); ';
  put '        call symputx(cats(''type'',_n_),type,''l''); ';
  put '        if last then call symputx(''nobs'',_n_,''l''); ';
  put '      run; ';
  put '      data &fmtds; ';
  put '        /* rename on entry */ ';
  put '        set &ds(rename=( ';
  put '      %local i; ';
  put '      %do i=1 %to &nobs; ';
  put '        &&name&i=&&newname&i ';
  put '      %end; ';
  put '        )); ';
  put '      %do i=1 %to &nobs; ';
  put '        length &&name&i $&&len&i; ';
  put '        &&name&i=left(put(&&newname&i,&&fmt&i)); ';
  put '        drop &&newname&i; ';
  put '      %end; ';
  put '        if _error_ then call symputx(''syscc'',1012); ';
  put '      run; ';
  put '      %let ds=&fmtds; ';
  put '    %end; /* &fmt=Y */ ';
  put '    data _null_;file &jref mod encoding=''utf-8''; ';
  put '      put "["; call symputx(''cols'',0,''l''); ';
  put '    proc sort ';
  put '      data=sashelp.vcolumn(where=(libname=''WORK'' & memname="%upcase(&ds)")) ';
  put '      out=_data_; ';
  put '      by varnum; ';
  put ' ';
  put '    data _null_; ';
  put '      set _last_ end=last; ';
  put '      call symputx(cats(''name'',_n_),name,''l''); ';
  put '      call symputx(cats(''type'',_n_),type,''l''); ';
  put '      call symputx(cats(''len'',_n_),length,''l''); ';
  put '      if last then call symputx(''cols'',_n_,''l''); ';
  put '    run; ';
  put ' ';
  put '    proc format; /* credit yabwon for special null removal */ ';
  put '      value bart ._ - .z = null ';
  put '      other = [best.]; ';
  put ' ';
  put '    data;run; %let tempds=&syslast; /* temp table for spesh char management */ ';
  put '    proc sql; drop table &tempds; ';
  put '    data &tempds/view=&tempds; ';
  put '      attrib _all_ label=''''; ';
  put '      %do i=1 %to &cols; ';
  put '        %if &&type&i=char %then %do; ';
  put '          length &&name&i $32767; ';
  put '          format &&name&i $32767.; ';
  put '        %end; ';
  put '      %end; ';
  put '      set &ds; ';
  put '      format _numeric_ bart.; ';
  put '    %do i=1 %to &cols; ';
  put '      %if &&type&i=char %then %do; ';
  put '        &&name&i=''"''!!trim(prxchange(''s/"/\"/'',-1, ';
  put '                    prxchange(''s/''!!''0A''x!!''/\n/'',-1, ';
  put '                    prxchange(''s/''!!''0D''x!!''/\r/'',-1, ';
  put '                    prxchange(''s/''!!''09''x!!''/\t/'',-1, ';
  put '                    prxchange(''s/\\/\\\\/'',-1,&&name&i) ';
  put '        )))))!!''"''; ';
  put '      %end; ';
  put '    %end; ';
  put '    run; ';
  put '    /* write to temp loc to avoid _webout truncation ';
  put '      - https://support.sas.com/kb/49/325.html */ ';
  put '    filename _sjs temp lrecl=131068 encoding=''utf-8''; ';
  put '    data _null_; file _sjs lrecl=131068 encoding=''utf-8'' mod; ';
  put '      set &tempds; ';
  put '      if _n_>1 then put "," @; put ';
  put '      %if &action=ARR %then "[" ; %else "{" ; ';
  put '      %do i=1 %to &cols; ';
  put '        %if &i>1 %then  "," ; ';
  put '        %if &action=OBJ %then """&&name&i"":" ; ';
  put '        &&name&i ';
  put '      %end; ';
  put '      %if &action=ARR %then "]" ; %else "}" ; ; ';
  put '    proc sql; ';
  put '    drop view &tempds; ';
  put '    /* now write the long strings to _webout 1 byte at a time */ ';
  put '    data _null_; ';
  put '      length filein 8 fileid 8; ';
  put '      filein = fopen("_sjs",''I'',1,''B''); ';
  put '      fileid = fopen("&jref",''A'',1,''B''); ';
  put '      rec = ''20''x; ';
  put '      do while(fread(filein)=0); ';
  put '        rc = fget(filein,rec,1); ';
  put '        rc = fput(fileid, rec); ';
  put '        rc =fwrite(fileid); ';
  put '      end; ';
  put '      rc = fclose(filein); ';
  put '      rc = fclose(fileid); ';
  put '    run; ';
  put '    filename _sjs clear; ';
  put '    data _null_; file &jref mod encoding=''utf-8''; ';
  put '      put "]"; ';
  put '    run; ';
  put '  %end; ';
  put '%end; ';
  put ' ';
  put '%else %if &action=CLOSE %then %do; ';
  put '  data _null_;file &jref encoding=''utf-8'' mod; ';
  put '    put "}"; ';
  put '  run; ';
  put '%end; ';
  put '%mend mp_jsonout; ';
  put '%macro mm_webout(action,ds,dslabel=,fref=_webout,fmt=Y); ';
  put '%global _webin_file_count _webin_fileref1 _webin_name1 _program _debug ';
  put '  sasjs_tables; ';
  put '%local i tempds; ';
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
  put '      infile &&_webin_fileref&i termstr=crlf; ';
  put '      input; ';
  put '      call symputx(''input_statement'',_infile_); ';
  put '      putlog "&&_webin_name&i input statement: "  _infile_; ';
  put '      stop; ';
  put '    data &&_webin_name&i; ';
  put '      infile &&_webin_fileref&i firstobs=2 dsd termstr=crlf encoding=''utf-8''; ';
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
  put '  /* fix encoding */ ';
  put '  OPTIONS NOBOMFILE; ';
  put ' ';
  put '  /** ';
  put '    * check engine type to avoid the below err message: ';
  put '    * > Function is only valid for filerefs using the CACHE access method. ';
  put '    */ ';
  put '  data _null_; ';
  put '    set sashelp.vextfl(where=(fileref="_WEBOUT")); ';
  put '    if xengine=''STREAM'' then do; ';
  put '      rc=stpsrv_header(''Content-type'',"text/html; encoding=utf-8"); ';
  put '    end; ';
  put '  run; ';
  put ' ';
  put '  /* setup json */ ';
  put '  data _null_;file &fref encoding=''utf-8''; ';
  put '  %if %str(&_debug) ge 131 %then %do; ';
  put '    put ''>>weboutBEGIN<<''; ';
  put '  %end; ';
  put '    put ''{"START_DTTM" : "'' "%sysfunc(datetime(),datetime20.3)" ''"''; ';
  put '  run; ';
  put ' ';
  put '%end; ';
  put ' ';
  put '%else %if &action=ARR or &action=OBJ %then %do; ';
  put '  %mp_jsonout(&action,&ds,dslabel=&dslabel,fmt=&fmt,jref=&fref ';
  put '    ,engine=DATASTEP,dbg=%str(&_debug) ';
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
  put '      if not (name =:"DATA"); ';
  put '      i+1; ';
  put '      call symputx(''wt''!!left(i),name,''l''); ';
  put '      call symputx(''wtcnt'',i,''l''); ';
  put '    data _null_; file &fref mod encoding=''utf-8''; ';
  put '      put ",""WORK"":{"; ';
  put '    %do i=1 %to &wtcnt; ';
  put '      %let wt=&&wt&i; ';
  put '      proc contents noprint data=&wt ';
  put '        out=_data_ (keep=name type length format:); ';
  put '      run;%let tempds=%scan(&syslast,2,.); ';
  put '      data _null_; file &fref mod encoding=''utf-8''; ';
  put '        dsid=open("WORK.&wt",''is''); ';
  put '        nlobs=attrn(dsid,''NLOBS''); ';
  put '        nvars=attrn(dsid,''NVARS''); ';
  put '        rc=close(dsid); ';
  put '        if &i>1 then put '',''@; ';
  put '        put " ""&wt"" : {"; ';
  put '        put ''"nlobs":'' nlobs; ';
  put '        put '',"nvars":'' nvars; ';
  put '      %mp_jsonout(OBJ,&tempds,jref=&fref,dslabel=colattrs,engine=DATASTEP) ';
  put '      %mp_jsonout(OBJ,&wt,jref=&fref,dslabel=first10rows,engine=DATASTEP) ';
  put '      data _null_; file &fref mod encoding=''utf-8''; ';
  put '        put "}"; ';
  put '    %end; ';
  put '    data _null_; file &fref mod encoding=''utf-8''; ';
  put '      put "}"; ';
  put '    run; ';
  put '  %end; ';
  put '  /* close off json */ ';
  put '  data _null_;file &fref mod encoding=''utf-8''; ';
  put '    _PROGRAM=quote(trim(resolve(symget(''_PROGRAM'')))); ';
  put '    put ",""SYSUSERID"" : ""&sysuserid"" "; ';
  put '    put ",""MF_GETUSER"" : ""%mf_getuser()"" "; ';
  put '    put ",""_DEBUG"" : ""&_debug"" "; ';
  put '    _METAUSER=quote(trim(symget(''_METAUSER''))); ';
  put '    put ",""_METAUSER"": " _METAUSER; ';
  put '    _METAPERSON=quote(trim(symget(''_METAPERSON''))); ';
  put '    put '',"_METAPERSON": '' _METAPERSON; ';
  put '    put '',"_PROGRAM" : '' _PROGRAM ; ';
  put '    put ",""SYSCC"" : ""&syscc"" "; ';
  put '    put ",""SYSERRORTEXT"" : ""&syserrortext"" "; ';
  put '    put ",""SYSHOSTNAME"" : ""&syshostname"" "; ';
  put '    put ",""SYSJOBID"" : ""&sysjobid"" "; ';
  put '    put ",""SYSSITE"" : ""&syssite"" "; ';
  put '    sysvlong=quote(trim(symget(''sysvlong''))); ';
  put '    put '',"SYSVLONG" : '' sysvlong; ';
  put '    put ",""SYSWARNINGTEXT"" : ""&syswarningtext"" "; ';
  put '    put '',"END_DTTM" : "'' "%sysfunc(datetime(),datetime20.3)" ''" ''; ';
  put '    put "}" @; ';
  put '  %if %str(&_debug) ge 131 %then %do; ';
  put '    put ''>>weboutEND<<''; ';
  put '  %end; ';
  put '  run; ';
  put '%end; ';
  put ' ';
  put '%mend mm_webout; ';
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
  put '    %else %let user=%scan(&&&metavar,1,@); ';
  put '  %end; ';
  put '  %else %let user=&sysuserid; ';
  put ' ';
  put '  %quote(&user) ';
  put ' ';
  put '%mend; ';
/* WEBOUT END */
  put '%macro webout(action,ds,dslabel=,fmt=);';
  put '  %mm_webout(&action,ds=&ds,dslabel=&dslabel,fmt=&fmt)';
  put '%mend;';
run;

/* add precode and code */
%local work tmpfile;
%let work=%sysfunc(pathname(work));
%let tmpfile=__mm_createwebservice.temp;
%local x fref freflist mod;
%let freflist= &adapter &precode &code ;
%do x=1 %to %sysfunc(countw(&freflist));
  %if &x>1 %then %let mod=mod;

  %let fref=%scan(&freflist,&x);
  %put &sysmacroname: adding &fref;
  data _null_;
    file "&work/&tmpfile" lrecl=3000 &mod;
    infile &fref;
    input;
    put _infile_;
  run;
%end;

/* create the metadata folder if not already there */
%mm_createfolder(path=&path)
%if &syscc ge 4 %then %return;

%if %upcase(&replace)=YES %then %do;
  %mm_deletestp(target=&path/&name)
%end;

/* create the web service */
%mm_createstp(stpname=&name
  ,filename=&tmpfile
  ,directory=&work
  ,tree=&path
  ,stpdesc=&desc
  ,mDebug=&mdebug
  ,server=&server
  ,stptype=2)

/* find the web app url */
%local url;
%let url=localhost/SASStoredProcess;
data _null_;
  length url $128;
  rc=METADATA_GETURI("Stored Process Web App",url);
  if rc=0 then call symputx('url',url,'l');
run;

%put ;%put ;%put ;%put ;%put ;%put ;
%put &sysmacroname: STP &name successfully created in &path;
%put ;%put ;%put ;
%put Check it out here:;
%put ;%put ;%put ;
%put &url?_PROGRAM=&path/&name;
%put ;%put ;%put ;%put ;%put ;%put ;

%mend;
