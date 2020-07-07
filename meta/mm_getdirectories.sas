/**
  @file
  @brief Returns a dataset with the meta directory object for a physical path
  @details Provide a file path to get matching directory objects, or leave
    blank to return all directories.  The Directory object is used to reference
    a physical filepath (eg when registering a .sas program in a Stored process)

  @param path= the physical path for which to return a meta Directory object
  @param outds= the dataset to create that contains the list of directories
  @param mDebug= set to 1 to show debug messages in the log

  @returns outds  dataset containing the following columns:
   - directoryuri
   - groupname
   - groupdesc

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getDirectories(
     path=
    ,outds=work.mm_getDirectories
    ,mDebug=0
)/*/STORE SOURCE*/;

%local mD;
%if &mDebug=1 %then %let mD=;
%else %let mD=%str(*);
%&mD.put Executing mm_getDirectories.sas;
%&mD.put _local_;

data &outds (keep=directoryuri name directoryname directorydesc );
  length directoryuri name directoryname directorydesc $256;
  call missing(of _all_);
  __i+1;
%if %length(&path)=0 %then %do;
  do while
  (metadata_getnobj("omsobj:Directory?@Id contains '.'",__i,directoryuri)>0);
%end; %else %do;
  do while
  (metadata_getnobj("omsobj:Directory?@DirectoryName='&path'",__i,directoryuri)>0);
%end;
    __rc1=metadata_getattr(directoryuri, "Name", name);
    __rc2=metadata_getattr(directoryuri, "DirectoryName", directoryname);
    __rc3=metadata_getattr(directoryuri, "Desc", directorydesc);
    &mD.putlog (_all_) (=);
    drop __:;
    __i+1;
    if sum(of __rc1-__rc3)=0 then output;
  end;
run;

%mend;
