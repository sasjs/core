/**
  @file
  @brief Export dataset metadata to a single output table
  @details Exports the dataset attributes and enginehost information, then
  converts the datasets into a single output table in the following format:

|ODS_TABLE:$10.|NAME:$100.|VALUE:$1000.|
|---|---|---|
|`ATTRIBUTES `|`Data Set Name `|`SASHELP.CLASS `|
|`ATTRIBUTES `|`Observations `|`19 `|
|`ATTRIBUTES `|`Member Type `|`DATA `|
|`ATTRIBUTES `|`Variables `|`5 `|
|`ATTRIBUTES `|`Engine `|`V9 `|
|`ATTRIBUTES `|`Indexes `|`0 `|
|`ATTRIBUTES `|`Created `|`06/08/2020 00:59:14 `|
|`ATTRIBUTES `|`Observation Length `|`40 `|
|`ATTRIBUTES `|`Last Modified `|`06/08/2020 00:59:14 `|
|`ATTRIBUTES `|`Deleted Observations `|`0 `|
|`ATTRIBUTES `|`Protection `|`. `|
|`ATTRIBUTES `|`Compressed `|`NO `|
|`ATTRIBUTES `|`Data Set Type `|`. `|
|`ATTRIBUTES `|`Sorted `|`NO `|
|`ATTRIBUTES `|`Label `|`Student Data `|
|`ATTRIBUTES `|`Data Representation `|`SOLARIS_X86_64, LINUX_X86_64, ALPHA_TRU64, LINUX_IA64 `|
|`ATTRIBUTES `|`Encoding `|`us-ascii  ASCII (ANSI) `|
|`ENGINEHOST `|`Data Set Page Size `|`65536 `|
|`ENGINEHOST `|`Number of Data Set Pages `|`1 `|
|`ENGINEHOST `|`First Data Page `|`1 `|
|`ENGINEHOST `|`Max Obs per Page `|`1632 `|
|`ENGINEHOST `|`Obs in First Data Page `|`19 `|
|`ENGINEHOST `|`Number of Data Set Repairs `|`0 `|
|`ENGINEHOST `|`Filename `|`/opt/sas/sas9/SASHome/SASFoundation/9.4/sashelp/class.sas7bdat `|
|`ENGINEHOST `|`Release Created `|`9.0401M7 `|
|`ENGINEHOST `|`Host Created `|`Linux `|
|`ENGINEHOST `|`Inode Number `|`28314616 `|
|`ENGINEHOST `|`Access Permission `|`rw-r--r-- `|
|`ENGINEHOST `|`Owner Name `|`sas `|
|`ENGINEHOST `|`File Size `|`128KB `|
|`ENGINEHOST `|`File Size (bytes) `|`131072 `|

  Example usage:

      %mp_dsmeta(work.sashelp,outds=work.mymeta)
      proc print data=work.mymeta;
      run;

  @param libds The library.dataset to export the metadata for
  @param outds= (work.dsmeta) The output table to contain the metadata

  <h4> Related Files </h4>
  @li mp_dsmeta.test.sas

**/

%macro mp_dsmeta(libds,outds=work.dsmeta);

%local ds1 ds2;
data;run; %let ds1=&syslast;
data;run; %let ds2=&syslast;

/* setup the ODS capture */
ods output attributes=&ds1 enginehost=&ds2;

/* export the metadata */
proc contents data=&libds;
run;

/* load it into a single table */
data &outds (keep=ods_table name value);
  length ods_table $10 name label1 label $100 value cvalue1 cvalue $1000
    nvalue nvalue1 nvalue2 8;
  if _n_=1 then call missing (of _all_);
  * putlog (_all_)(=);
  set &ds1 (in=atrs) &ds2 (in=eng);
  if atrs then do;
    ods_table='ATTRIBUTES';
    name=coalescec(label1,label);
    value=coalescec(cvalue1,cvalue,put(coalesce(nvalue1,nvalue),best.));
    output;
    if label2 ne '' then do;
    name=label2;
    value=coalescec(cvalue2,put(nvalue2,best.));
    output;
    end;
  end;
  else if eng then do;
    ods_table='ENGINEHOST';
    name=coalescec(label1,label);
    value=coalescec(cvalue1,cvalue,put(coalesce(nvalue1,nvalue),best.));
    output;
  end;
run;

proc sql;
drop table &ds1, &ds2;

%mend mp_dsmeta;

