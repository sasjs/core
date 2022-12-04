/**
  @file
  @brief Send data to/from sasjs/server
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


  @param [in] action Either FETCH, OPEN, ARR, OBJ or CLOSE
  @param [in] ds The dataset to send back to the frontend
  @param [out] dslabel= value to use instead of table name for sending to JSON
  @param [in] fmt= (N) Setting Y converts all vars to their formatted values
  @param [out] fref= (_webout) The fileref to which to write the JSON
  @param [in] missing= (NULL) Special numeric missing values can be sent as NULL
    (eg `null`) or as STRING values (eg `".a"` or `".b"`)
  @param [in] showmeta= (N) Set to Y to output metadata alongside each table,
    such as the column formats and types.  The metadata is contained inside an
    object with the same name as the table but prefixed with a dollar sign - ie,
    `,"$tablename":{"formats":{"col1":"$CHAR1"},"types":{"COL1":"C"}}`
  @param [in] workobs= (0) When set to a positive integer, will create a new
    output object (WORK) which contains this number of observations from all
    tables in the WORK library.
  @param [in] maxobs= (MAX) Provide an integer to limit the number of input rows
    that should be converted to output JSON

  <h4> SAS Macros </h4>
  @li mf_getuser.sas
  @li mp_jsonout.sas
  @li mfs_httpheader.sas

  <h4> Related Macros </h4>
  @li mv_webout.sas
  @li mm_webout.sas

  @version 9.3
  @author Allan Bowe

**/

%macro ms_webout(action,ds,dslabel=,fref=_webout,fmt=N,missing=NULL
  ,showmeta=N,maxobs=MAX,workobs=0
);
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
      infile &&_webin_fileref&i termstr=crlf lrecl=32767;
      input;
      call symputx('input_statement',_infile_);
      putlog "&&_webin_name&i input statement: "  _infile_;
      stop;
    data &&_webin_name&i;
      infile &&_webin_fileref&i firstobs=2 dsd termstr=crlf encoding='utf-8'
        lrecl=32767;
      input &input_statement;
      %if %str(&_debug) ge 131 %then %do;
        if _n_<20 then putlog _infile_;
      %end;
    run;
    %let sasjs_tables=&sasjs_tables &&_webin_name&i;
  %end;
%end;

%else %if &action=OPEN %then %do;
  /* fix encoding and ensure enough lrecl */
  OPTIONS NOBOMFILE lrecl=32767;

  /* set the header */
  %mfs_httpheader(Content-type,application/json)

  /* setup json.  */
  data _null_;file &fref encoding='utf-8' termstr=lf ;
    put '{"SYSDATE" : "' "&SYSDATE" '"';
    put ',"SYSTIME" : "' "&SYSTIME" '"';
  run;

%end;

%else %if &action=ARR or &action=OBJ %then %do;
  %if "%substr(&sysver,1,1)"="4" or "%substr(&sysver,1,1)"="5" %then %do;
    /* functions in formats unsupported */
    %put &sysmacroname: forcing missing back to NULL as feature not supported;
    %let missing=NULL;
  %end;
  %mp_jsonout(&action,&ds,dslabel=&dslabel,fmt=&fmt,jref=&fref
    ,engine=DATASTEP,missing=&missing,showmeta=&showmeta,maxobs=&maxobs
  )
%end;
%else %if &action=CLOSE %then %do;
  %if %str(&workobs) > 0 %then %do;
    /* if debug mode, send back first XX records of each work table also */
    data;run;%let tempds=%scan(&syslast,2,.);
    ods output Members=&tempds;
    proc datasets library=WORK memtype=data;
    %local wtcnt;%let wtcnt=0;
    data _null_;
      set &tempds;
      if not (upcase(name) =:"DATA"); /* ignore temp datasets */
      if not (upcase(name)=:"_DATA_");
      i+1;
      call symputx(cats('wt',i),name,'l');
      call symputx('wtcnt',i,'l');
    data _null_; file &fref mod encoding='utf-8' termstr=lf;
      put ",""WORK"":{";
    %do i=1 %to &wtcnt;
      %let wt=&&wt&i;
      data _null_; file &fref mod encoding='utf-8' termstr=lf;
        dsid=open("WORK.&wt",'is');
        nlobs=attrn(dsid,'NLOBS');
        nvars=attrn(dsid,'NVARS');
        rc=close(dsid);
        if &i>1 then put ','@;
        put " ""&wt"" : {";
        put '"nlobs":' nlobs;
        put ',"nvars":' nvars;
      %mp_jsonout(OBJ,&wt,jref=&fref,dslabel=first10rows,showmeta=Y,maxobs=10
        ,maxobs=&workobs
      )
      data _null_; file &fref mod encoding='utf-8' termstr=lf;
        put "}";
    %end;
    data _null_; file &fref mod encoding='utf-8' termstr=lf;
      put "}";
    run;
  %end;
  /* close off json */
  data _null_;file &fref mod encoding='utf-8' termstr=lf lrecl=32767;
    length SYSPROCESSNAME syserrortext syswarningtext autoexec $512;
    put ",""_DEBUG"" : ""&_debug"" ";
    _PROGRAM=quote(trim(resolve(symget('_PROGRAM'))));
    put ',"_PROGRAM" : ' _PROGRAM ;
    autoexec=quote(urlencode(trim(getoption('autoexec'))));
    put ',"AUTOEXEC" : ' autoexec;
    put ",""MF_GETUSER"" : ""%mf_getuser()"" ";
    put ",""SYSCC"" : ""&syscc"" ";
    put ",""SYSENCODING"" : ""&sysencoding"" ";
    syserrortext=cats(symget('syserrortext'));
    if findc(syserrortext,'"\'!!'0A0D09000E0F010210111A'x) then do;
      syserrortext='"'!!trim(
        prxchange('s/"/\\"/',-1,        /* double quote */
        prxchange('s/\x0A/\n/',-1,      /* new line */
        prxchange('s/\x0D/\r/',-1,      /* carriage return */
        prxchange('s/\x09/\\t/',-1,     /* tab */
        prxchange('s/\x00/\\u0000/',-1, /* NUL */
        prxchange('s/\x0E/\\u000E/',-1, /* SS  */
        prxchange('s/\x0F/\\u000F/',-1, /* SF  */
        prxchange('s/\x01/\\u0001/',-1, /* SOH */
        prxchange('s/\x02/\\u0002/',-1, /* STX */
        prxchange('s/\x10/\\u0010/',-1, /* DLE */
        prxchange('s/\x11/\\u0011/',-1, /* DC1 */
        prxchange('s/\x1A/\\u001A/',-1, /* SUB */
        prxchange('s/\\/\\\\/',-1,syserrortext)
      )))))))))))))!!'"';
    end;
    put ',"SYSERRORTEXT" : ' syserrortext;
    SYSHOSTINFOLONG=quote(trim(symget('SYSHOSTINFOLONG')));
    put ',"SYSHOSTINFOLONG" : ' SYSHOSTINFOLONG;
    put ",""SYSHOSTNAME"" : ""&syshostname"" ";
    put ",""SYSPROCESSID"" : ""&SYSPROCESSID"" ";
    put ",""SYSPROCESSMODE"" : ""&SYSPROCESSMODE"" ";
    SYSPROCESSNAME=quote(urlencode(cats(SYSPROCESSNAME)));
    put ",""SYSPROCESSNAME"" : " SYSPROCESSNAME;
    put ",""SYSJOBID"" : ""&sysjobid"" ";
    put ",""SYSSCPL"" : ""&sysscpl"" ";
    put ",""SYSSITE"" : ""&syssite"" ";
    put ",""SYSTCPIPHOSTNAME"" : ""&SYSTCPIPHOSTNAME"" ";
    put ",""SYSUSERID"" : ""&sysuserid"" ";
    sysvlong=quote(trim(symget('sysvlong')));
    put ',"SYSVLONG" : ' sysvlong;
    syswarningtext=cats(symget('syswarningtext'));
    if findc(syswarningtext,'"\'!!'0A0D09000E0F010210111A'x) then do;
      syswarningtext='"'!!trim(
        prxchange('s/"/\\"/',-1,        /* double quote */
        prxchange('s/\x0A/\n/',-1,      /* new line */
        prxchange('s/\x0D/\r/',-1,      /* carriage return */
        prxchange('s/\x09/\\t/',-1,     /* tab */
        prxchange('s/\x00/\\u0000/',-1, /* NUL */
        prxchange('s/\x0E/\\u000E/',-1, /* SS  */
        prxchange('s/\x0F/\\u000F/',-1, /* SF  */
        prxchange('s/\x01/\\u0001/',-1, /* SOH */
        prxchange('s/\x02/\\u0002/',-1, /* STX */
        prxchange('s/\x10/\\u0010/',-1, /* DLE */
        prxchange('s/\x11/\\u0011/',-1, /* DC1 */
        prxchange('s/\x1A/\\u001A/',-1, /* SUB */
        prxchange('s/\\/\\\\/',-1,syswarningtext)
      )))))))))))))!!'"';
    end;
    put ',"SYSWARNINGTEXT" : ' syswarningtext;
    put ',"END_DTTM" : "' "%sysfunc(datetime(),E8601DT26.6)" '" ';
    length memsize $32;
    memsize="%sysfunc(INPUTN(%sysfunc(getoption(memsize)), best.),sizekmg.)";
    memsize=quote(cats(memsize));
    put ',"MEMSIZE" : ' memsize;
    put "}" @;
  run;
%end;

%mend ms_webout;
