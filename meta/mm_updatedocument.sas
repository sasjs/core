/**
  @file
  @brief Update the TextStore in a Document with the same name
  @details Enables arbitrary content to be stored in a document object

  Usage:

    %mm_updatedocument(path=/my/metadata/path
      ,name=docname
      ,text="/file/system/some.txt")


  @param [in] path= the BIP Tree folder path
  @param [in] name=Document Name
  @param [in] text=a source file containing the text to be added

  @param [in] frefin= change default inref if it clashes with an existing one
  @param [out] frefout= change default outref if it clashes with an existing one
  @param [in] mDebug= set to 1 to show debug messages in the log

  @version 9.3
  @author Allan Bowe

**/

%macro mm_updatedocument(path=
  ,name=
  ,text=
  ,frefin=inmeta
  ,frefout=outmeta
  ,mdebug=0
);
/* first, check if STP exists */
%local tsuri;
%let tsuri=stopifempty ;

data _null_;
  format type uri tsuri value $200.;
  call missing (of _all_);
  path="&path/&name(Note)";
  /* first, find the STP ID */
  if metadata_pathobj("",path,"Note",type,uri)>0 then do;
    /* get sourcetext */
    cnt=1;
    do while (metadata_getnasn(uri,"Notes",cnt,tsuri)>0);
      rc=metadata_getattr(tsuri,"Name",value);
      put tsuri= value=;
      if value="&name" then do;
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
  %put %str(WARN)ING:  &path/&name.(Document) not found!;
  %return;
%end;

%if %length(&text)<2 %then %do;
  %put %str(WARN)ING:  No text supplied!!;
  %return;
%end;

filename &frefin temp recfm=n;

/* escape code so it can be stored as XML */
/* input file may be over 32k wide, so deal with one char at a time */
data _null_;
  file &frefin recfm=n;
  infile &text recfm=n;
  input instr $CHAR1. ;
  if _n_=1 then put "<UpdateMetadata><Reposid>$METAREPOSITORY</Reposid>
    <Metadata><TextStore id='&tsuri' StoredText='" @@;
  select (instr);
    when ('&') put '&amp;';
    when ('<') put '&lt;';
    when ('>') put '&gt;';
    when ("'") put '&apos;';
    when ('"') put '&quot;';
    when ('0A'x) put '&#x0a;';
    when ('0D'x) put '&#x0d;';
    when ('$') put '&#36;';
    otherwise put instr $CHAR1.;
  end;
run;

data _null_;
  file &frefin mod;
  put "'></TextStore></Metadata><NS>SAS</NS><Flags>268435456</Flags>
    </UpdateMetadata>";
run;


filename &frefout temp;

proc metadata in= &frefin
  %if &mdebug=1 %then out=&frefout verbose;
;
run;

%if &mdebug=1 %then %do;
  /* write the response to the log for debugging */
  data _null_;
    infile &frefout lrecl=1048576;
    input;
    put _infile_;
  run;
%end;

%mend mm_updatedocument;