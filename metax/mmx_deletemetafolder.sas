/**
  @file
  @brief Deletes a metadata folder
  @details Deletes a metadata folder (and contents) using the batch tools, as
    documented here:
    https://documentation.sas.com/?docsetId=bisag&docsetTarget=p0zqp8fmgs4o0kn1tt7j8ho829fv.htm&docsetVersion=9.4&locale=en

  Usage:

      %mmx_deletemetafolder(loc=/some/meta/folder,user=sasdemo,pass=mars345)

  <h4> SAS Macros </h4>
  @li mf_loc.sas

  @param [in] loc= the metadata folder to delete
  @param [in] user= username
  @param [in] pass= password

  @version 9.4
  @author Allan Bowe

**/

%macro mmx_deletemetafolder(loc=,user=,pass=);

%local host port path connx_string;
%let host=%sysfunc(getoption(metaserver));
%let port=%sysfunc(getoption(metaport));
%let path=%mf_loc(POF)/tools;

%let connx_string= -host &host -port &port -user '&user' -password '&pass';
/* remove directory */
data _null_;
  infile " &path/sas-delete-objects &connx_string ""&loc"" -deleteContents 2>&1"
    pipe lrecl=10000;
  input;
  putlog _infile_;
run;

%mend mmx_deletemetafolder;
