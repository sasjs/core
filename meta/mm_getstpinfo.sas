/**
  @file
  @brief Get the properties of a Stored Process
  @details Extracts various properties and creates an output table in the
  structure below:

|STP_URI:$200.|SERVERCONTEXT:$200.|STOREDPROCESSCONFIGURATION:$1000.|SOURCECODE_FIRST32K:$32767.|PATH:$76.|
|---|---|---|---|---|
|`A5DN9TDQ.BH0000C8 `|`SASApp `|`<?xml version="1.0" encoding="UTF-8"?><StoredProcess><ServerContext LogicalServerType="Sps" OtherAllowed="false"/><ResultCapabilities Package="false" Streaming="true"/><OutputParameters/></StoredProcess> `|`%put first 32767 bytes of code; `|`/path/to/my/stp`|

  @param [in] pgm The metadata path of the Stored Process
  @param [out] outds= (work.mm_getstpinfo) The output table to create
  @param [in] mdebug= (0) Set to 1 to enable DEBUG messages

  <h4> Related Files </h4>
  @li mm_getstpcode.sas
  @li mm_getstps.sas
  @li mm_createstp.sas
  @li mm_deletestp.sas

**/

%macro mm_getstpinfo(pgm
  ,outds=work.mm_getstpinfo
  ,mDebug=0
);

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing &sysmacroname..sas;
%&mD.put _local_;

data &outds;
  length type stp_uri tsuri servercontext value $200
    StoredProcessConfiguration $1000 sourcecode_first32k $32767;
  keep path stp_uri sourcecode_first32k StoredProcessConfiguration
    servercontext;
  call missing (of _all_);
  path="&pgm(StoredProcess)";
  /* first, find the STP ID */
  if metadata_pathobj("",path,"StoredProcess",type,stp_uri)>0 then do;
    /* get attributes */
    cnt=1;
    do while (metadata_getnasn(stp_uri,"Notes",cnt,tsuri)>0);
      rc1=metadata_getattr(tsuri,"Name",value);
      &mD.put tsuri= value=;
      if value="SourceCode" then do;
        rc2=metadata_getattr(tsuri,"StoredText",sourcecode_first32k);
      end;
      else if value="Stored Process" then do;
        rc3=metadata_getattr(tsuri,"StoredText",StoredProcessConfiguration);
      end;
      cnt+1;
    end;
    /* get context (should only be one) */
    rc4=metadata_getnasn(stp_uri,"ComputeLocations",1,tsuri);
    rc5=metadata_getattr(tsuri,"Name",servercontext);
  end;
  else do;
    put "%str(ERR)OR: could not find " pgm;
    put (_all_)(=);
  end;
  &md.put (_all_)(=);
run;

%mend mm_getstpinfo ;
