/**
  @file mm_gettableid.sas
  @brief Get the metadata id for a particular table
  @details Provide a libref and table name to return the corresponding metadata
  in an output datataset.

  Usage:

      - get a table id
      %mm_gettableid(libref=METALIB,ds=SOMETABLE,outds=iwant)

  @param [in] libref= The libref to search
  @param [in] ds= The input dataset to check
  @param [out] outds= the dataset to create that contains the `tableuri`
  @param [in] mDebug= set to 1 to show debug messages in the log

  @returns outds  dataset containing `tableuri` and `tablename`

  @version 9.3
  @author Allan Bowe

**/

%macro mm_gettableid(
    libref=
    ,ds=
    ,outds=work.mm_gettableid
    ,mDebug=0
)/*/STORE SOURCE*/;

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing &sysmacroname..sas;
%&mD.put _local_;

data &outds;
  length uri usingpkguri id type tableuri tablename tmpuri $256;
  call missing(of _all_);
  keep tableuri tablename;
  n=1;
  rc=0;
  if metadata_getnobj("omsobj:SASLibrary?@Libref='&libref'",n,uri)<1 then do;
    put "Library &libref not found";
    stop;
  end;
  &mD.putlog "uri is " uri;
  if metadata_getnasn(uri, "UsingPackages", 1, usingpkguri)>0 then do;
    rc=metadata_resolve(usingpkguri,type,id);
    &mD.putlog "Type is " type;
  end;

  if type='DatabaseSchema' then tmpuri=usingpkguri;
  else tmpuri=uri;

  t=1;
  do while(metadata_getnasn(tmpuri, "Tables", t, tableuri)>0);
    t+1;
    rc= metadata_getattr(tableuri, "Name", tablename);
    &mD.putlog "Table is " tablename;
    if upcase(tablename)="%upcase(&ds)" then do;
      output;
    end;
  end;
run;

%mend mm_gettableid;