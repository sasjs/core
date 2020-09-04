/**
  @file
  @brief Retrieves properties of the SAS web app server
  @details 
  Usage:

      %mm_getwebappsrvprops(outds= some_ds)
      data _null_;
        set some_ds(where=(name='webappsrv.server.url'));
        put value=;
      run;

  @param outds the dataset to create that contains the list of properties

  @returns outds  dataset containing all properties

  @warning The following filenames are created and then de-assigned:

      filename __in clear;
      filename __out clear;
      libname __shake clear;

  @version 9.4
  @author Allan Bowe
  @source https://github.com/sasjs/core

**/

%macro mm_getwebappsrvprops(
    outds= mm_getwebappsrvprops
)/*/STORE SOURCE*/;

filename __in temp lrecl=10000;
filename __out temp lrecl=10000;
filename __shake temp lrecl=10000;
data _null_ ;
   file __in ;
   put '<GetMetadataObjects>' ;
   put '<Reposid>$METAREPOSITORY</Reposid>' ;
   put '<Type>TextStore</Type>' ;
   put '<NS>SAS</NS>' ;
    put '<Flags>388</Flags>' ;
   put '<Options>' ;
    put '<XMLSelect search="TextStore[@Name='@@;
    put "'Public Configuration Properties']" @@;
     put '[Objects/SoftwareComponent[@ClassIdentifier=''webappsrv'']]' ;
   put '"/>';
   put '<Templates>' ;
   put '<TextStore StoredText="">' ;
   put '</TextStore>' ;
   put '</Templates>' ;
   put '</Options>' ;
   put '</GetMetadataObjects>' ;
run ;
proc metadata in=__in out=__out verbose;run;

/* find the beginning of the text */
%local start;
%let start=0;
data _null_;
  infile __out lrecl=10000;
  input;
  length cleartemplate $32000;
  cleartemplate=tranwrd(_infile_,'StoredText=""','');
  start=index(cleartemplate,'StoredText="');
  if start then do;
    call symputx("start",start+11+length('StoredText=""')-1);
    putlog cleartemplate ;
  end;
  stop;
run;
%put &=start;
%if &start>0 %then %do;
  /* read the content, byte by byte, resolving escaped chars */
  data _null_;
  length filein 8 fileid 8;
  filein = fopen("__out","I",1,"B");
  fileid = fopen("__shake","O",1,"B");
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
          otherwise putlog "WARNING: missing value for " entity=;
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
  data &outds ;
    infile __shake dlm='=' missover;
    length name $50 value $500;
    input name $ value $;
  run;
%end;
%else %do;
  %put NOTE: Unable to retrieve Web App Server Properties;
  data &outds;
    length name $50 value $500;
  run;
%end;

/* clear references */
filename __in clear;
filename __out clear;
filename __shake clear;

%mend;