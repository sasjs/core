/**
  @file
  @brief Writes the TextStore of a Document Object to an external file
  @details If the document exists, and has a textstore object, the contents
    of that textstore are written to an external file.

  usage:

      %mm_getdocument(tree=/some/meta/path
        ,name=someDocument
        ,outref=/some/unquoted/filename.ext
      )

  <h4> SAS Macros </h4>
  @li mp_abort.sas

  @param [in] tree= The metadata path of the document
  @param [in] name= Document object name.
  @param [out] outref= full and unquoted path to the desired text file.
    This will be overwritten if it already exists.

  @author Allan Bowe

**/

%macro mm_getdocument(
    tree=/User Folders/sasdemo
    ,name=myNote
    ,outref=%sysfunc(pathname(work))/mm_getdocument.txt
    ,mDebug=1
    );

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing &sysmacroname..sas;
%&mD.put _local_;

/**
  * check tree exists
  */

data _null_;
  length type uri $256;
  rc=metadata_pathobj("","&tree","Folder",type,uri);
  call symputx('type',type,'l');
  call symputx('treeuri',uri,'l');
run;

%mp_abort(
  iftrue= (&type ne Tree)
  ,mac=mm_getdocument.sas
  ,msg=Tree &tree does not exist!
)

/**
  * Check object exists
  */
data _null_;
  length type docuri tsuri tsid $256 ;
  rc1=metadata_pathobj("","&tree/&name","Note",type,docuri);
  rc2=metadata_getnasn(docuri,"Notes",1,tsuri);
  rc3=metadata_getattr(tsuri,"Id",tsid);
  call symputx('type',type,'l');
  call symputx("tsid",tsid,'l');
  putlog (_all_)(=);
run;

%mp_abort(
  iftrue= (&type ne Document)
  ,mac=mm_getdocument.sas
  ,msg=Document &name could not be found in &tree!
)

/**
  * Now we can extract the textstore
  */
filename __getdoc temp lrecl=10000000;
proc metadata
  in="<GetMetadata><Reposid>$METAREPOSITORY</Reposid>
      <Metadata><TextStore Id='&tsid'/></Metadata>
      <Ns>SAS</Ns><Flags>1</Flags><Options/></GetMetadata>"
  out=__getdoc ;
run;

/* find the beginning of the text */
data _null_;
  infile __getdoc lrecl=10000;
  input;
  start=index(_infile_,'StoredText="');
  if start then do;
    call symputx("start",start+11);
    put start= "type=&type";
    putlog '"' _infile_ '"';
  end;
  stop;

/* read the content, byte by byte, resolving escaped chars */
filename __outdoc "&outref" lrecl=100000;
data _null_;
  length filein 8 fileid 8;
  filein = fopen("__getdoc","I",1,"B");
  fileid = fopen("__outdoc","O",1,"B");
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
filename __getdoc clear;
filename __outdoc clear;

%mend mm_getdocument;
