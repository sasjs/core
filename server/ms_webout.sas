/**
  @file
  @brief Send data to/from @sasjs/server
  @details This macro should be added to the start of each web service,
  **immediately** followed by a call to:

        %ms_webout(FETCH)

    This will read all the input data and create same-named SAS datasets in the
    WORK library.  You can then insert your code, and send data back using the
    following syntax:

        data some datasets; * make some data ;
          retain some columns;
        run;

        %ms_webout(OPEN)
        %ms_webout(ARR,some)  * Array format, fast, suitable for large tables ;
        %ms_webout(OBJ,datasets) * Object format, easier to work with ;
        %ms_webout(CLOSE)


  @param action Either FETCH, OPEN, ARR, OBJ or CLOSE
  @param ds The dataset to send back to the frontend
  @param dslabel= value to use instead of the real name for sending to JSON
  @param fmt=(Y) Set to N to send back unformatted values
  @param fref=(_webout) The fileref to which to write the JSON

  <h4> SAS Macros </h4>
  @li mp_jsonout.sas
  @li mf_getuser.sas

  <h4> Related Macros </h4>
  @li mv_webout.sas
  @li mm_webout.sas

  @version 9.3
  @author Allan Bowe

**/

%macro ms_webout(action,ds,dslabel=,fref=_webout,fmt=Y);
%global _webin_file_count _webin_fileref1 _webin_name1 _program _debug
  sasjs_tables;

%local i tempds;
%let action=%upcase(&action);

%if &action=FETCH %then %do;
  %if %str(&_debug) ge 131 %then %do;
    options mprint notes mprintnest;
  %end;
  %let _webin_file_count=%eval(&_webin_file_count+0);
  /* now read in the data */
  %do i=1 %to &_webin_file_count;
    %if &_webin_file_count=1 %then %do;
      %let _webin_fileref1=&_webin_fileref;
      %let _webin_name1=&_webin_name;
    %end;
    data _null_;
      infile &&_webin_fileref&i termstr=crlf;
      input;
      call symputx('input_statement',_infile_);
      putlog "&&_webin_name&i input statement: "  _infile_;
      stop;
    data &&_webin_name&i;
      infile &&_webin_fileref&i firstobs=2 dsd termstr=crlf encoding='utf-8';
      input &input_statement;
      %if %str(&_debug) ge 131 %then %do;
        if _n_<20 then putlog _infile_;
      %end;
    run;
    %let sasjs_tables=&sasjs_tables &&_webin_name&i;
  %end;
%end;

%else %if &action=OPEN %then %do;
  /* fix encoding */
  OPTIONS NOBOMFILE;

  /* setup json */
  data _null_;file &fref encoding='utf-8' termstr=lf;
  %if %str(&_debug) ge 131 %then %do;
    put '>>weboutBEGIN<<';
  %end;
    put '{"SYSDATE" : "' "&SYSDATE" '"';
    put ',"SYSTIME" : "' "&SYSTIME" '"';
  run;

%end;

%else %if &action=ARR or &action=OBJ %then %do;
  %mp_jsonout(&action,&ds,dslabel=&dslabel,fmt=&fmt,jref=&fref
    ,engine=DATASTEP,dbg=%str(&_debug)
  )
%end;
%else %if &action=CLOSE %then %do;
  %if %str(&_debug) ge 131 %then %do;
    /* if debug mode, send back first 10 records of each work table also */
    options obs=10;
    data;run;%let tempds=%scan(&syslast,2,.);
    ods output Members=&tempds;
    proc datasets library=WORK memtype=data;
    %local wtcnt;%let wtcnt=0;
    data _null_;
      set &tempds;
      if not (upcase(name) =:"DATA"); /* ignore temp datasets */
      i+1;
      call symputx('wt'!!left(i),name,'l');
      call symputx('wtcnt',i,'l');
    data _null_; file &fref mod encoding='utf-8' termstr=lf;
      put ",""WORK"":{";
    %do i=1 %to &wtcnt;
      %let wt=&&wt&i;
      proc contents noprint data=&wt
        out=_data_ (keep=name type length format:);
      run;%let tempds=%scan(&syslast,2,.);
      data _null_; file &fref mod encoding='utf-8' termstr=lf;
        dsid=open("WORK.&wt",'is');
        nlobs=attrn(dsid,'NLOBS');
        nvars=attrn(dsid,'NVARS');
        rc=close(dsid);
        if &i>1 then put ','@;
        put " ""&wt"" : {";
        put '"nlobs":' nlobs;
        put ',"nvars":' nvars;
      %mp_jsonout(OBJ,&tempds,jref=&fref,dslabel=colattrs,engine=DATASTEP)
      %mp_jsonout(OBJ,&wt,jref=&fref,dslabel=first10rows,engine=DATASTEP)
      data _null_; file &fref mod encoding='utf-8' termstr=lf;
        put "}";
    %end;
    data _null_; file &fref mod encoding='utf-8' termstr=lf termstr=lf;
      put "}";
    run;
  %end;
  /* close off json */
  data _null_;file &fref mod encoding='utf-8' termstr=lf;
    _PROGRAM=quote(trim(resolve(symget('_PROGRAM'))));
    put ",""SYSUSERID"" : ""&sysuserid"" ";
    put ",""MF_GETUSER"" : ""%mf_getuser()"" ";
    put ",""_DEBUG"" : ""&_debug"" ";
    put ',"_PROGRAM" : ' _PROGRAM ;
    put ",""SYSCC"" : ""&syscc"" ";
    put ",""SYSERRORTEXT"" : ""&syserrortext"" ";
    SYSHOSTINFOLONG=quote(trim(symget('SYSHOSTINFOLONG')));
    put ',"SYSHOSTINFOLONG" : ' SYSHOSTINFOLONG;
    put ",""SYSHOSTNAME"" : ""&syshostname"" ";
    put ",""SYSPROCESSID"" : ""&SYSPROCESSID"" ";
    put ",""SYSPROCESSMODE"" : ""&SYSPROCESSMODE"" ";
    length SYSPROCESSNAME $512;
    SYSPROCESSNAME=quote(urlencode(cats(SYSPROCESSNAME)));
    put ",""SYSPROCESSNAME"" : " SYSPROCESSNAME;
    put ",""SYSJOBID"" : ""&sysjobid"" ";
    put ",""SYSSCPL"" : ""&sysscpl"" ";
    put ",""SYSSITE"" : ""&syssite"" ";
    put ",""SYSTCPIPHOSTNAME"" : ""&SYSTCPIPHOSTNAME"" ";
    sysvlong=quote(trim(symget('sysvlong')));
    put ',"SYSVLONG" : ' sysvlong;
    put ",""SYSWARNINGTEXT"" : ""&syswarningtext"" ";
    put ',"END_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '" ';
    length autoexec $512;
    autoexec=quote(urlencode(trim(getoption('autoexec'))));
    put ',"AUTOEXEC" : ' autoexec;
    memsize="%sysfunc(INPUTN(%sysfunc(getoption(memsize)), best.),sizekmg.)";
    memsize=quote(cats(memsize));
    put ',"MEMSIZE" : ' memsize;
    put "}" @;
  %if %str(&_debug) ge 131 %then %do;
    put '>>weboutEND<<';
  %end;
  run;
%end;

%mend ms_webout;
