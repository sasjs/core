/**
  @file
  @brief Send data to/from the SAS Viya Job Execution Service
  @details This macro should be added to the start of each Job Execution
  Service, **immediately** followed by a call to:

        %mv_webout(FETCH)

    This will read all the input data and create same-named SAS datasets in the
    WORK library.  You can then insert your code, and send data back using the
    following syntax:

        data some datasets; * make some data ;
          retain some columns;
        run;

        %mv_webout(OPEN)
        %mv_webout(ARR,some)  * Array format, fast, suitable for large tables ;
        %mv_webout(OBJ,datasets) * Object format, easier to work with ;
        %mv_webout(CLOSE)


  @param [in] action Either OPEN, ARR, OBJ or CLOSE
  @param [in] ds The dataset to send back to the frontend
  @param [in] _webout= fileref for returning the json
  @param [out] fref=(_mvwtemp) Temp fileref to which to write the output
  @param [out] dslabel= value to use instead of table name for sending to JSON
  @param [in] fmt= (N) Setting Y converts all vars to their formatted values
  @param [in] stream=(Y) Change to N if not streaming to _webout
  @param [in] missing= (NULL) Special numeric missing values can be sent as NULL
    (eg `null`) or as STRING values (eg `".a"` or `".b"`)
  @param [in] showmeta= (N) Set to Y to output metadata alongside each table,
    such as the column formats and types.  The metadata is contained inside an
    object with the same name as the table but prefixed with a dollar sign - ie,
    `,"$tablename":{"formats":{"col1":"$CHAR1"},"types":{"COL1":"C"}}`
  @param [in] maxobs= (MAX) Provide an integer to limit the number of input rows
    that should be converted to output JSON
  @param [in] workobs= (0) When set to a positive integer, will create a new
    output object (WORK) which contains this number of observations from all
    tables in the WORK library.

  <h4> SAS Macros </h4>
  @li mp_jsonout.sas
  @li mf_getuser.sas

  <h4> Related Macros </h4>
  @li ms_webout.sas
  @li mm_webout.sas

  @version Viya 3.3
  @author Allan Bowe, source: https://github.com/sasjs/core

**/
%macro mv_webout(action,ds,fref=_mvwtemp,dslabel=,fmt=N,stream=Y,missing=NULL
  ,showmeta=N,maxobs=MAX,workobs=0
);
%global _webin_file_count _webin_fileuri _debug _omittextlog _webin_name
  sasjs_tables SYS_JES_JOB_URI;
%if %index("&_debug",log) %then %let _debug=131;

%local i tempds table;
%let action=%upcase(&action);

%if &action=FETCH %then %do;
  %if %upcase(&_omittextlog)=FALSE or %str(&_debug) ge 131 %then %do;
    options mprint notes mprintnest;
  %end;

  %if not %symexist(_webin_fileuri1) %then %do;
    %let _webin_file_count=%eval(&_webin_file_count+0);
    %let _webin_fileuri1=&_webin_fileuri;
    %let _webin_name1=&_webin_name;
  %end;

  /* if the sasjs_tables param is passed, we expect param based upload */
  %if %length(&sasjs_tables.X)>1 %then %do;

    /* convert data from macro variables to datasets */
    %do i=1 %to %sysfunc(countw(&sasjs_tables));
      %let table=%scan(&sasjs_tables,&i,%str( ));
      %if %symexist(sasjs&i.data0)=0 %then %let sasjs&i.data0=1;
      data _null_;
        file "%sysfunc(pathname(work))/&table..csv" recfm=n;
        retain nrflg 0;
        length line $32767;
        do i=1 to &&sasjs&i.data0;
          if &&sasjs&i.data0=1 then line=symget("sasjs&i.data");
          else line=symget(cats("sasjs&i.data",i));
          if i=1 and substr(line,1,7)='%nrstr(' then do;
            nrflg=1;
            line=substr(line,8);
          end;
          if i=&&sasjs&i.data0 and nrflg=1 then do;
            line=substr(line,1,length(line)-1);
          end;
          put line +(-1) @;
        end;
      run;
      data _null_;
        infile "%sysfunc(pathname(work))/&table..csv" termstr=crlf ;
        input;
        if _n_=1 then call symputx('input_statement',_infile_);
        list;
      data work.&table;
        infile "%sysfunc(pathname(work))/&table..csv" firstobs=2 dsd
          termstr=crlf;
        input &input_statement;
      run;
    %end;
  %end;
  %else %do i=1 %to &_webin_file_count;
    /* read in any files that are sent */
    /* this part needs refactoring for wide files */
    filename indata filesrvc "&&_webin_fileuri&i" lrecl=999999;
    data _null_;
      infile indata termstr=crlf lrecl=32767;
      input;
      if _n_=1 then call symputx('input_statement',_infile_);
      %if %str(&_debug) ge 131 %then %do;
        if _n_<20 then putlog _infile_;
        else stop;
      %end;
      %else %do;
        stop;
      %end;
    run;
    data &&_webin_name&i;
      infile indata firstobs=2 dsd termstr=crlf ;
      input &input_statement;
    run;
    %let sasjs_tables=&sasjs_tables &&_webin_name&i;
  %end;
%end;
%else %if &action=OPEN %then %do;
  /* setup webout */
  OPTIONS NOBOMFILE;
  %if "X&SYS_JES_JOB_URI.X"="XX" %then %do;
    filename _webout temp lrecl=999999 mod;
  %end;
  %else %do;
    filename _webout filesrvc parenturi="&SYS_JES_JOB_URI"
      name="_webout.json" lrecl=999999 mod;
  %end;

  /* setup temp ref */
  %if %upcase(&fref) ne _WEBOUT %then %do;
    filename &fref temp lrecl=999999 permission='A::u::rwx,A::g::rw-,A::o::---';
  %end;

  /* setup json */
  data _null_;file &fref;
    put '{"SYSDATE" : "' "&SYSDATE" '"';
    put ',"SYSTIME" : "' "&SYSTIME" '"';
  run;
%end;
%else %if &action=ARR or &action=OBJ %then %do;
    %mp_jsonout(&action,&ds,dslabel=&dslabel,fmt=&fmt,jref=&fref
      ,engine=DATASTEP,missing=&missing,showmeta=&showmeta,maxobs=&maxobs
    )
%end;
%else %if &action=CLOSE %then %do;
  %if %str(&workobs) > 0 %then %do;
    /* send back first XX records of each work table for debugging */
    data;run;%let tempds=%scan(&syslast,2,.);
    ods output Members=&tempds;
    proc datasets library=WORK memtype=data;
    %local wtcnt;%let wtcnt=0;
    data _null_;
      set &tempds;
      if not (upcase(name) =:"DATA"); /* ignore temp datasets */
      i+1;
      call symputx(cats('wt',i),name,'l');
      call symputx('wtcnt',i,'l');
    data _null_; file &fref mod; put ",""WORK"":{";
    %do i=1 %to &wtcnt;
      %let wt=&&wt&i;
      data _null_; file &fref mod;
        dsid=open("WORK.&wt",'is');
        nlobs=attrn(dsid,'NLOBS');
        nvars=attrn(dsid,'NVARS');
        rc=close(dsid);
        if &i>1 then put ','@;
        put " ""&wt"" : {";
        put '"nlobs":' nlobs;
        put ',"nvars":' nvars;
      %mp_jsonout(OBJ,&wt,jref=&fref,dslabel=first10rows,showmeta=Y
        ,maxobs=&workobs
      )
      data _null_; file &fref mod;put "}";
    %end;
    data _null_; file &fref mod;put "}";run;
  %end;

  /* close off json */
  data _null_;file &fref mod;
    length SYSPROCESSNAME syserrortext syswarningtext autoexec $512;
    put ",""_DEBUG"" : ""&_debug"" ";
    _PROGRAM=quote(trim(resolve(symget('_PROGRAM'))));
    put ',"_PROGRAM" : ' _PROGRAM ;
    autoexec=quote(urlencode(trim(getoption('autoexec'))));
    put ',"AUTOEXEC" : ' autoexec;
    put ",""MF_GETUSER"" : ""%mf_getuser()"" ";
    SYS_JES_JOB_URI=quote(trim(resolve(symget('SYS_JES_JOB_URI'))));
    put ',"SYS_JES_JOB_URI" : ' SYS_JES_JOB_URI ;
    put ",""SYSJOBID"" : ""&sysjobid"" ";
    put ",""SYSCC"" : ""&syscc"" ";
    syserrortext=cats('"',tranwrd(symget('syserrortext'),'"','\"'),'"');
    put ',"SYSERRORTEXT" : ' syserrortext;
    put ",""SYSHOSTNAME"" : ""&syshostname"" ";
    put ",""SYSPROCESSID"" : ""&SYSPROCESSID"" ";
    put ",""SYSPROCESSMODE"" : ""&SYSPROCESSMODE"" ";
    SYSPROCESSNAME=quote(urlencode(cats(SYSPROCESSNAME)));
    put ",""SYSPROCESSNAME"" : " SYSPROCESSNAME;
    put ",""SYSJOBID"" : ""&sysjobid"" ";
    put ",""SYSSCPL"" : ""&sysscpl"" ";
    put ",""SYSSITE"" : ""&syssite"" ";
    put ",""SYSUSERID"" : ""&sysuserid"" ";
    sysvlong=quote(trim(symget('sysvlong')));
    put ',"SYSVLONG" : ' sysvlong;
    syswarningtext=cats('"',tranwrd(symget('syswarningtext'),'"','\"'),'"');
    put ',"SYSWARNINGTEXT" : ' syswarningtext;
    put ',"END_DTTM" : "' "%sysfunc(datetime(),E8601DT26.6)" '" ';
    length memsize $32;
    memsize="%sysfunc(INPUTN(%sysfunc(getoption(memsize)), best.),sizekmg.)";
    memsize=quote(cats(memsize));
    put ',"MEMSIZE" : ' memsize;
    put "}";

  %if %upcase(&fref) ne _WEBOUT and &stream=Y %then %do;
    data _null_; rc=fcopy("&fref","_webout");run;
  %end;

%end;

%mend mv_webout;
