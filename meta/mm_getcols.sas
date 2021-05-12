/**
  @file
  @brief Creates a dataset with all metadata columns for a particular table
  @details

  usage:

    %mm_getcols(tableuri=A5X8AHW1.B40001S5)

  @param outds the dataset to create that contains the list of columns
  @param uri the uri of the table for which to return columns

  @returns outds  dataset containing all columns, specifically:
    - colname
    - coluri
    - coldesc

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getcols(
    tableuri=
    ,outds=work.mm_getcols
)/*/STORE SOURCE*/;

data &outds;
  keep col: SAS:;
  length assoc uri coluri colname coldesc SASColumnType SASFormat SASInformat
      SASPrecision SASColumnLength $256;
  call missing (of _all_);
  uri=symget('tableuri');
  n=1;
  do while (metadata_getnasn(uri,'Columns',n,coluri)>0);
    rc3=metadata_getattr(coluri,"Name",colname);
    rc3=metadata_getattr(coluri,"Desc",coldesc);
    rc4=metadata_getattr(coluri,"SASColumnType",SASColumnType);
    rc5=metadata_getattr(coluri,"SASFormat",SASFormat);
    rc6=metadata_getattr(coluri,"SASInformat",SASInformat);
    rc7=metadata_getattr(coluri,"SASPrecision",SASPrecision);
    rc8=metadata_getattr(coluri,"SASColumnLength",SASColumnLength);
    output;
    call missing(colname,coldesc,SASColumnType,SASFormat,SASInformat
      ,SASPrecision,SASColumnLength);
    n+1;
  end;
run;
proc sort;
  by colname;
run;

%mend;