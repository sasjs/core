/**
  @file
  @brief Creates a metadata folder
  @details Creates a metadata folder using the batch tools

  Usage:

      %mmx_createmetafolder(loc=/some/meta/folder,user=sasdemo,pass=mars345)

  <h4> SAS Macros </h4>
  @li mf_loc.sas
  @li mp_abort.sas

  @param loc= the metadata folder to delete
  @param user= username
  @param pass= password

  @version 9.4
  @author Allan Bowe

**/

%macro mmx_createmetafolder(loc=,user=,pass=);

%local host port path connx_string msg;
%let host=%sysfunc(getoption(metaserver));
%let port=%sysfunc(getoption(metaport));
%let path=%mf_loc(POF)/tools;

%let connx_string= -host &host -port &port -user '&user' -password '&pass';
/* remove directory */
data _null_;
  infile " &path/sas-make-folder &connx_string ""&loc"" -makeFullPath 2>&1"
    pipe lrecl=10000;
  input;
  putlog _infile_;
run;

data _null_; /* check tree exists */
  length type uri $256;
  rc=metadata_pathobj("","&loc","Folder",type,uri);
  call symputx('foldertype',type,'l');
run;
%let msg=Location (&loc) was not created!!;
%mp_abort(iftrue= (&foldertype ne Tree)
  ,mac=&_program..sas
  ,msg=%superq(msg)
)

%mend mmx_createmetafolder;
