/**
  @file mp_jsonout.sas
  @brief Writes JSON in SASjs format to a fileref
  @details PROC JSON is faster but will produce errs like the ones below if
  special chars are encountered.

     >An object or array close is not valid at this point in the JSON text.
     >Date value out of range

  If this happens, try running with ENGINE=DATASTEP.

  Usage:

        filename tmp temp;
        data class; set sashelp.class;run;
        
        %mp_jsonout(OBJ,class,jref=tmp)

        data _null_;
        infile tmp;
        input;list;
        run;

  If you are building web apps with SAS then you are strongly encouraged to use
  the mX_createwebservice macros in combination with the 
  [sasjs adapter](https://github.com/sasjs/adapter).
  For more information see https://sasjs.io

  @param action Valid values:
    * OPEN - opens the JSON
    * OBJ - sends a table with each row as an object
    * ARR - sends a table with each row in an array
    * CLOSE - closes the JSON

  @param ds the dataset to send.  Must be a work table.
  @param jref= the fileref to which to send the JSON
  @param dslabel= the name to give the table in the exported JSON
  @param fmt= Whether to keep or strip formats from the table
  @param engine= Which engine to use to send the JSON, options are:
  * PROCJSON (default)
  * DATASTEP 

  @param dbg= Typically used with an _debug (numeric) option

  @version 9.2
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mp_jsonout(action,ds,jref=_webout,dslabel=,fmt=Y,engine=PROCJSON,dbg=0
)/*/STORE SOURCE*/;
%put output location=&jref;
%if &action=OPEN %then %do;
  data _null_;file &jref encoding='utf-8';
    put '{"START_DTTM" : "' "%sysfunc(datetime(),datetime20.3)" '"';
  run;
%end;
%else %if (&action=ARR or &action=OBJ) %then %do;
  options validvarname=upcase;
  data _null_;file &jref mod encoding='utf-8';
    put ", ""%lowcase(%sysfunc(coalescec(&dslabel,&ds)))"":";

  %if &engine=PROCJSON %then %do;
    data;run;%let tempds=&syslast;
    proc sql;drop table &tempds;
    data &tempds /view=&tempds;set &ds; 
    %if &fmt=N %then format _numeric_ best32.;;
    proc json out=&jref
        %if &action=ARR %then nokeys ;
        %if &dbg ge 131  %then pretty ;
        ;export &tempds / nosastags fmtnumeric;
    run;
    proc sql;drop view &tempds;
  %end;
  %else %if &engine=DATASTEP %then %do;
    %local cols i tempds;
    %let cols=0;
    %if %sysfunc(exist(&ds)) ne 1 & %sysfunc(exist(&ds,VIEW)) ne 1 %then %do;
      %put &sysmacroname:  &ds NOT FOUND!!!;
      %return;
    %end;
    data _null_;file &jref mod ; 
      put "["; call symputx('cols',0,'l');
    proc sort data=sashelp.vcolumn(where=(libname='WORK' & memname="%upcase(&ds)"))
      out=_data_;
      by varnum;

    data _null_; 
      set _last_ end=last;
      call symputx(cats('name',_n_),name,'l');
      call symputx(cats('type',_n_),type,'l');
      call symputx(cats('len',_n_),length,'l');
      if last then call symputx('cols',_n_,'l');
    run;

    proc format; /* credit yabwon for special null removal */
      value bart ._ - .z = null
      other = [best.];

    data;run; %let tempds=&syslast; /* temp table for spesh char management */
    proc sql; drop table &tempds;
    data &tempds/view=&tempds;
      attrib _all_ label='';
      %do i=1 %to &cols;
        %if &&type&i=char %then %do;
          length &&name&i $32767;
          format &&name&i $32767.;
        %end;
      %end;
      set &ds;
      format _numeric_ bart.;
    %do i=1 %to &cols;
      %if &&type&i=char %then %do;
        &&name&i='"'!!trim(prxchange('s/"/\"/',-1,
                    prxchange('s/'!!'0A'x!!'/\n/',-1,
                    prxchange('s/'!!'0D'x!!'/\r/',-1,
                    prxchange('s/'!!'09'x!!'/\t/',-1,
                    prxchange('s/\\/\\\\/',-1,&&name&i)
        )))))!!'"';
      %end;
    %end;
    run; 
    /* write to temp loc to avoid _webout truncation - https://support.sas.com/kb/49/325.html */
    filename _sjs temp lrecl=131068 encoding='utf-8';
    data _null_; file _sjs lrecl=131068 encoding='utf-8' mod;
      set &tempds;
      if _n_>1 then put "," @; put
      %if &action=ARR %then "[" ; %else "{" ;
      %do i=1 %to &cols;
        %if &i>1 %then  "," ;
        %if &action=OBJ %then """&&name&i"":" ;
        &&name&i 
      %end;
      %if &action=ARR %then "]" ; %else "}" ; ;
    proc sql;
    drop view &tempds;
    /* now write the long strings to _webout 1 byte at a time */
    data _null_;
      length filein 8 fileid 8;
      filein = fopen("_sjs",'I',1,'B');
      fileid = fopen("&jref",'A',1,'B');
      rec = '20'x;
      do while(fread(filein)=0);
        rc = fget(filein,rec,1);
        rc = fput(fileid, rec);
        rc =fwrite(fileid);
      end;
      rc = fclose(filein);
      rc = fclose(fileid);
    run;
    filename _sjs clear;
    data _null_; file &jref mod encoding='utf-8';
      put "]";
    run;
  %end;
%end;

%else %if &action=CLOSE %then %do;
  data _null_;file &jref encoding='utf-8';
    put "}";
  run;
%end;
%mend;