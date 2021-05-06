/**
  @file
  @brief Writes the code of an STP to an external file
  @details Fetches the SAS code from a Stored Process where the code is stored
  in metadata.

  Usage:

      %mm_getstpcode(tree=/some/meta/path
        ,name=someSTP
        ,outloc=/some/unquoted/filename.ext
      )

  @param [in] tree= The metadata path of the Stored Process (can also contain
    name)
  @param [in] name= Stored Process name.  Leave blank if included above.
  @param [out] outloc= (0) full and unquoted path to the desired text file.
    This will be overwritten if it already exists.
  @param [out] outref= (0) Fileref to which to write the code.
  @param [out] showlog=(NO) Set to YES to print log to the window

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas

  @author Allan Bowe

**/

%macro mm_getstpcode(
    tree=/User Folders/sasdemo/somestp
    ,name=
    ,outloc=0
    ,outref=0
    ,mDebug=1
    ,showlog=NO
    );

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing &sysmacroname..sas;
%&mD.put _local_;

%if %length(&name)>0 %then %let name=/&name;

/* first, check if STP exists */
%local tsuri;
%let tsuri=stopifempty ;

data _null_;
  format type uri tsuri value $200.;
  call missing (of _all_);
  path="&tree&name(StoredProcess)";
  /* first, find the STP ID */
  if metadata_pathobj("",path,"StoredProcess",type,uri)>0 then do;
    /* get sourcecode */
    cnt=1;
    do while (metadata_getnasn(uri,"Notes",cnt,tsuri)>0);
      rc=metadata_getattr(tsuri,"Name",value);
      put tsuri= value=;
      if value="SourceCode" then do;
        /* found it! */
        rc=metadata_getattr(tsuri,"Id",value);
        call symputx('tsuri',value,'l');
        stop;
      end;
      cnt+1;
    end;
  end;
  else put (_all_)(=);
run;

%if &tsuri=stopifempty %then %do;
  %put %str(WARN)ING:  &tree&name.(StoredProcess) not found!;
  %return;
%end;


/**
  * Now we can extract the textstore
  */
filename __getdoc temp lrecl=10000000;
proc metadata
  in="<GetMetadata><Reposid>$METAREPOSITORY</Reposid>
      <Metadata><TextStore Id='&tsuri'/></Metadata>
      <Ns>SAS</Ns><Flags>1</Flags><Options/></GetMetadata>"
  out=__getdoc ;
run;

/* find the beginning of the text */
%local start;
data _null_;
  infile __getdoc lrecl=10000;
  input;
  start=index(_infile_,'StoredText="');
  if start then do;
    call symputx("start",start+11);
    *putlog '"' _infile_ '"';
  end;
  stop;

%local outeng;
%if "&outloc"="0" %then %let outeng=TEMP;
%else %let outeng="&outloc";
%local fref;
%if &outref=0 %then %let fref=%mf_getuniquefileref();
%else %let fref=&outref;

/* read the content, byte by byte, resolving escaped chars */
filename &fref &outeng lrecl=100000;
data _null_;
  length filein 8 fileid 8;
  filein = fopen("__getdoc","I",1,"B");
  fileid = fopen("&fref","O",1,"B");
  rec = "20"x;
  length entity $6;
  do while(fread(filein)=0);
    x+1;
    if x>&start then do;
      rc = fget(filein,rec,1);
      if rec='"' then leave;
      else if rec="&" then do;
        entity=rec;
        do until (rec=";");
          if fread(filein) ne 0 then goto getout;
          rc = fget(filein,rec,1);
          entity=cats(entity,rec);
        end;
        select (entity);
          when ('&amp;' ) rec='&'  ;
          when ('&lt;'  ) rec='<'  ;
          when ('&gt;'  ) rec='>'  ;
          when ('&apos;') rec="'"  ;
          when ('&quot;') rec='"'  ;
          when ('&#x0a;') rec='0A'x;
          when ('&#x0d;') rec='0D'x;
          when ('&#36;' ) rec='$'  ;
          when ('&#x09;') rec='09'x;
          otherwise putlog "%str(WARN)ING: missing value for " entity=;
        end;
        rc =fput(fileid, substr(rec,1,1));
        rc =fwrite(fileid);
      end;
      else do;
        rc =fput(fileid,rec);
        rc =fwrite(fileid);
      end;
    end;
  end;
  getout:
  rc=fclose(filein);
  rc=fclose(fileid);
run;

%if &showlog=YES %then %do;
  data _null_;
    infile &fref lrecl=32767 end=last;
    input;
    if _n_=1 then putlog '>>stpcodeBEGIN<<';
    putlog _infile_;
    if last then putlog '>>stpcodeEND<<';
  run;
%end;

filename __getdoc clear;
%if &outref=0 %then %do;
  filename &fref clear;
%end;

%mend mm_getstpcode;
