/**
  @file
  @brief Update the source code of a type 2 STP
  @details Uploads the contents of a text file or fileref to an existing type 2
    STP.  A type 2 STP has its source code saved in metadata.

  Usage:

      %mm_updatestpsourcecode(stp=/my/metadata/path/mystpname
        ,stpcode="/file/system/source.sas")

  @param [in] stp= the BIP Tree folder path plus Stored Process Name
  @param [in] stpcode= the source file (or fileref) containing the SAS code to load
    into the stp.  For multiple files, they should simply be concatenated first.
  @param [in] minify= set to YES in order to strip comments, blank lines, and CRLFs.
  @param mDebug= set to 1 to show debug messages in the log

  @version 9.3
  @author Allan Bowe

  <h4> SAS Macros </h4>
  @li mf_getuniquefileref.sas

**/

%macro mm_updatestpsourcecode(stp=
  ,stpcode=
  ,minify=NO
  ,mdebug=0
);

/* first, check if STP exists */
%local tsuri;
%let tsuri=stopifempty ;

data _null_;
  format type uri tsuri value $200.;
  call missing (of _all_);
  path="&stp.(StoredProcess)";
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
  %put %str(WARN)ING:  &stp.(StoredProcess) not found!;
  %return;
%end;

%if %length(&stpcode)<2 %then %do;
  %put %str(WARN)ING:  No SAS code supplied!!;
  %return;
%end;

%local frefin frefout;
%let frefin=%mf_getuniquefileref();
%let frefout=%mf_getuniquefileref();

/* write header XML */
data _null_;
  file &frefin;
  put "<UpdateMetadata><Reposid>$METAREPOSITORY</Reposid>
    <Metadata><TextStore id='&tsuri' StoredText='";
run;

/* escape code so it can be stored as XML */
/* write contents */
%if %length(&stpcode)>2 %then %do;
  data _null_;
    file &frefin lrecl=32767 mod;
    infile &stpcode lrecl=32767;
    length outstr $32767;
    input outstr ;
    /* escape code so it can be stored as XML */
    outstr=tranwrd(_infile_,'&','&amp;');
    outstr=tranwrd(outstr,'<','&lt;');
    outstr=tranwrd(outstr,'>','&gt;');
    outstr=tranwrd(outstr,"'",'&apos;');
    outstr=tranwrd(outstr,'"','&quot;');
    outstr=tranwrd(outstr,'0A'x,'&#x0a;');
    outstr=tranwrd(outstr,'0D'x,'&#x0d;');
    outstr=tranwrd(outstr,'$','&#36;');
    %if &minify=YES %then %do;
      outstr=cats(outstr);
      if outstr ne '';
      if not (outstr=:'/*' and subpad(left(reverse(outstr)),1,2)='/*');
    %end;
    outstr=trim(outstr);
    put outstr '&#10;';
  run;
%end;

data _null_;
  file &frefin mod;
  put "'></TextStore></Metadata><NS>SAS</NS><Flags>268435456</Flags>
    </UpdateMetadata>";
run;

proc metadata in= &frefin out=&frefout;
run;

%if &mdebug=1 %then %do;
  /* write the response to the log for debugging */
  data _null_;
    infile &frefout lrecl=32767;
    input;
    put _infile_;
  run;
%end;
%else %do;
  filename &frefin clear;
  filename &frefout clear;
%end;

%mend mm_updatestpsourcecode;