/**
  @file mp_jsonout.sas
  @brief Writes JSON in SASjs format to a fileref
  @details PROC JSON is faster but will produce errs like the ones below if
  special chars are encountered.

  > (ERR)OR: Some code points did not transcode.

  > An object or array close is not valid at this point in the JSON text.

  > Date value out of range

  If this happens, try running with ENGINE=DATASTEP.

  Usage:

        filename tmp temp;
        data class; set sashelp.class;run;

        %mp_jsonout(OPEN,jref=tmp)
        %mp_jsonout(OBJ,class,jref=tmp)
        %mp_jsonout(OBJ,class,dslabel=class2,jref=tmp,showmeta=YES)
        %mp_jsonout(CLOSE,jref=tmp)

        data _null_;
        infile tmp;
        input;putlog _infile_;
        run;

  If you are building web apps with SAS then you are strongly encouraged to use
  the mX_createwebservice macros in combination with the
  [sasjs adapter](https://github.com/sasjs/adapter).
  For more information see https://sasjs.io

  @param [in] action Valid values:
    @li OPEN - opens the JSON
    @li OBJ - sends a table with each row as an object
    @li ARR - sends a table with each row in an array
    @li CLOSE - closes the JSON
  @param [in] ds The dataset to send.  Must be a work table.
  @param [out] jref= (_webout) The fileref to which to send the JSON
  @param [out] dslabel= The name to give the table in the exported JSON
  @param [in] fmt= (Y) Whether to keep (Y) or strip (N) formats from the table
  @param [in] engine= (DATASTEP) Which engine to use to send the JSON. Options:
    @li PROCJSON (default)
    @li DATASTEP (more reliable when data has non standard characters)
  @param [in] missing= (NULL) Special numeric missing values can be sent as NULL
    (eg `null`) or as STRING values (eg `".a"` or `".b"`)
  @param [in] showmeta= (NO) Set to YES to output metadata alongside each table,
    such as the column formats and types.  The metadata is contained inside an
    object with the same name as the table but prefixed with a dollar sign - ie,
    `,"$tablename":{"formats":{"col1":"$CHAR1"},"types":{"COL1":"C"}}`

  <h4> Related Macros <h4>
  @li mp_ds2fmtds.sas

  @version 9.2
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_jsonout(action,ds,jref=_webout,dslabel=,fmt=Y
  ,engine=DATASTEP
  ,missing=NULL
  ,showmeta=NO
)/*/STORE SOURCE*/;
%local tempds colinfo fmtds i numcols;
%let numcols=0;

%if &action=OPEN %then %do;
  options nobomfile;
  data _null_;file &jref encoding='utf-8' lrecl=200;
    put '{"PROCESSED_DTTM" : "' "%sysfunc(datetime(),E8601DT26.6)" '"';
  run;
%end;
%else %if (&action=ARR or &action=OBJ) %then %do;
  options validvarname=upcase;
  data _null_; file &jref encoding='utf-8' mod;
    put ", ""%lowcase(%sysfunc(coalescec(&dslabel,&ds)))"":";

  /* grab col defs */
  proc contents noprint data=&ds
    out=_data_(keep=name type length format formatl formatd varnum label);
  run;
  %let colinfo=%scan(&syslast,2,.);
  proc sort data=&colinfo;
    by varnum;
  run;
  /* move meta to mac vars */
  data _null_;
    if _n_=1 then call symputx('numcols',nobs,'l');
    set &colinfo end=last nobs=nobs;
    name=upcase(name);
    /* fix formats */
    if type=2 or type=6 then do;
      typelong='char';
      length fmt $49.;
      if format='' then fmt=cats('$',length,'.');
      else if formatl=0 then fmt=cats(format,'.');
      else fmt=cats(format,formatl,'.');
      newlen=max(formatl,length);
    end;
    else do;
      typelong='num';
      if format='' then fmt='best.';
      else if formatl=0 then fmt=cats(format,'.');
      else if formatd=0 then fmt=cats(format,formatl,'.');
      else fmt=cats(format,formatl,'.',formatd);
      /* needs to be wide, for datetimes etc */
      newlen=max(length,formatl,24);
    end;
    /* 32 char unique name */
    newname='sasjs'!!substr(cats(put(md5(name),$hex32.)),1,27);

    call symputx(cats('name',_n_),name,'l');
    call symputx(cats('newname',_n_),newname,'l');
    call symputx(cats('len',_n_),newlen,'l');
    call symputx(cats('length',_n_),length,'l');
    call symputx(cats('fmt',_n_),fmt,'l');
    call symputx(cats('type',_n_),type,'l');
    call symputx(cats('typelong',_n_),typelong,'l');
    call symputx(cats('label',_n_),coalescec(label,name),'l');
  run;

  %let tempds=%substr(_%sysfunc(compress(%sysfunc(uuidgen()),-)),1,32);

  %if &engine=PROCJSON %then %do;
    %if &missing=STRING %then %do;
      %put &sysmacroname: Special Missings not supported in proc json.;
      %put &sysmacroname: Switching to DATASTEP engine;
      %goto datastep;
    %end;
    data &tempds;set &ds;
    %if &fmt=N %then format _numeric_ best32.;;
    /* PRETTY is necessary to avoid line truncation in large files */
    proc json out=&jref pretty
        %if &action=ARR %then nokeys ;
        ;export &tempds / nosastags fmtnumeric;
    run;
  %end;
  %else %if &engine=DATASTEP %then %do;
    %datastep:
    %if %sysfunc(exist(&ds)) ne 1 & %sysfunc(exist(&ds,VIEW)) ne 1
    %then %do;
      %put &sysmacroname:  &ds NOT FOUND!!!;
      %return;
    %end;

    %if &fmt=Y %then %do;
      data _data_;
        /* rename on entry */
        set &ds(rename=(
      %do i=1 %to &numcols;
        &&name&i=&&newname&i
      %end;
        ));
      %do i=1 %to &numcols;
        length &&name&i $&&len&i;
        %if &&typelong&i=num %then %do;
          &&name&i=left(put(&&newname&i,&&fmt&i));
        %end;
        %else %do;
          &&name&i=put(&&newname&i,&&fmt&i);
        %end;
        drop &&newname&i;
      %end;
        if _error_ then call symputx('syscc',1012);
      run;
      %let fmtds=&syslast;
    %end;

    proc format; /* credit yabwon for special null removal */
    value bart (default=40)
    %if &missing=NULL %then %do;
      ._ - .z = null
    %end;
    %else %do;
      ._ = [quote()]
      . = null
      .a - .z = [quote()]
    %end;
      other = [best.];

    data &tempds;
      attrib _all_ label='';
      %do i=1 %to &numcols;
        %if &&typelong&i=char or &fmt=Y %then %do;
          length &&name&i $32767;
          format &&name&i $32767.;
        %end;
      %end;
      %if &fmt=Y %then %do;
        set &fmtds;
      %end;
      %else %do;
        set &ds;
      %end;
      format _numeric_ bart.;
    %do i=1 %to &numcols;
      %if &&typelong&i=char or &fmt=Y %then %do;
        if findc(&&name&i,'"\'!!'0A0D09000E0F01021011'x) then do;
          &&name&i='"'!!trim(
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
            prxchange('s/\\/\\\\/',-1,&&name&i)
          ))))))))))))!!'"';
        end;
        else &&name&i=quote(cats(&&name&i));
      %end;
    %end;
    run;

    /* write to temp loc to avoid _webout truncation
      - https://support.sas.com/kb/49/325.html */
    filename _sjs temp lrecl=131068 encoding='utf-8';
    data _null_; file _sjs lrecl=131068 encoding='utf-8' mod ;
      if _n_=1 then put "[";
      set &tempds;
      if _n_>1 then put "," @; put
      %if &action=ARR %then "[" ; %else "{" ;
      %do i=1 %to &numcols;
        %if &i>1 %then  "," ;
        %if &action=OBJ %then """&&name&i"":" ;
        "&&name&i"n /* name literal for reserved variable names */
      %end;
      %if &action=ARR %then "]" ; %else "}" ; ;
    /* now write the long strings to _webout 1 byte at a time */
    data _null_;
      length filein 8 fileid 8;
      filein=fopen("_sjs",'I',1,'B');
      fileid=fopen("&jref",'A',1,'B');
      rec='20'x;
      do while(fread(filein)=0);
        rc=fget(filein,rec,1);
        rc=fput(fileid, rec);
        rc=fwrite(fileid);
      end;
      /* close out the table */
      rc=fput(fileid, "]");
      rc=fwrite(fileid);
      rc=fclose(filein);
      rc=fclose(fileid);
    run;
    filename _sjs clear;
  %end;

  proc sql;
  drop table &colinfo, &tempds;

  %if &showmeta=YES %then %do;
    data _null_; file &jref encoding='utf-8' mod;
      put ", ""$%lowcase(%sysfunc(coalescec(&dslabel,&ds)))"":{""vars"":{";
      do i=1 to &numcols;
        name=quote(trim(symget(cats('name',i))));
        format=quote(trim(symget(cats('fmt',i))));
        label=quote(prxchange('s/\\/\\\\/',-1,trim(symget(cats('label',i)))));
        length=quote(trim(symget(cats('length',i))));
        type=quote(trim(symget(cats('typelong',i))));
        if i>1 then put "," @@;
        put name ':{"format":' format ',"label":' label
          ',"length":' length ',"type":' type '}';
      end;
      put '}}';
    run;
  %end;
%end;

%else %if &action=CLOSE %then %do;
  data _null_; file &jref encoding='utf-8' mod ;
    put "}";
  run;
%end;
%mend mp_jsonout;
