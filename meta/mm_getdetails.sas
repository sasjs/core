/**
  @file mm_getdetails.sas
  @brief extracts metadata attributes and associations for a particular uri

  @param [in] uri the metadata object for which to return
    attributes / associations
  @param [out] outattrs= (work.attributes)
    The dataset to create that contains the list of attributes
  @param [out] outassocs= (work.associations)
    The dataset to contain the list of associations

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getdetails(uri
  ,outattrs=work.attributes
  ,outassocs=work.associations
  ,sortoptions=
)/*/STORE SOURCE*/;

data &outassocs;
  keep assoc assocuri name;
  length assoc assocuri name $256;
  call missing(of _all_);
  rc1=1;n1=1;
  do while(rc1>0);
    /* Walk through all possible associations of this object. */
    rc1=metadata_getnasl("&uri",n1,assoc);
    rc2=1;n2=1;
    do while(rc2>0);
      /* Walk through all the associations on this machine object. */
      rc2=metadata_getnasn("&uri",trim(assoc),n2,assocuri);
      if (rc2>0) then do;
        rc3=metadata_getattr(assocuri,"Name",name);
        output;
      end;
      call missing(name,assocuri);
      n2+1;
    end;
    n1+1;
  end;
run;
proc sort &sortoptions;
  by assoc name;
run;

data &outattrs;
  keep type name value;
  length type $4 name $256 value $32767;
  rc1=1;n1=1;type='Prop';name='';value='';
  do while(rc1>0);
    rc1=metadata_getnprp("&uri",n1,name,value);
    if rc1>0 then output;
    n1+1;
  end;
  rc1=1;n1=1;type='Attr';
  do while(rc1>0);
    rc1=metadata_getnatr("&uri",n1,name,value);
    if rc1>0 then output;
    n1+1;
  end;
run;
proc sort &sortoptions;
  by type name;
run;

%mend mm_getdetails;