/**
  @file mm_getservercontexts.sas
  @brief Creates a dataset with all server contexts in all repos
  @details
  Usage:

    %mm_getservercontexts(outds=mm_getservercontexts)

  @param outds= the dataset to create that contains the list

  @warning The following filenames are created and then de-assigned:

      filename __mc1 clear;
      filename __mc2 clear;
      libname __mc3 clear;

  <h4> Dependencies </h4>
  @li mm_getrepos.sas

  @version 9.3
  @author Allan Bowe

**/

%macro mm_getservercontexts(
  outds=work.mm_getrepos
)/*/STORE SOURCE*/;
%local repo repocnt x;
%let repo=%sysfunc(getoption(metarepository));

/* first get list of available repos */
%mm_getrepos(outds=work.repos)
%let repocnt=0;
data _null_;
  set repos;
  where repositorytype in('CUSTOM','FOUNDATION');
  keep id name ;
  call symputx('repo'!!left(_n_),name,'l');
  call symputx('repocnt',_n_,'l');
run;

filename __mc1 temp;
filename __mc2 temp;
data &outds; length serveruri servername $200; stop;run;
%do x=1 %to &repocnt;
  options metarepository=&&repo&x;
  proc metadata in=
  "<GetMetadataObjects><Reposid>$METAREPOSITORY</Reposid>
  <Type>ServerContext</Type><Objects/><NS>SAS</NS>
  <Flags>0</Flags><Options/></GetMetadataObjects>"
    out=__mc1;
  run;
  /*
  data _null_;
    infile __mc1 lrecl=1048576;
    input;
    put _infile_;
  run;
  */
  data _null_;
    file __mc2;
    put '<SXLEMAP version="1.2" name="SASContexts"><TABLE name="SASContexts">';
    put "<TABLE-PATH syntax='XPath'>/GetMetadataObjects/Objects/ServerContext</TABLE-PATH>";
    put '<COLUMN name="serveruri">';
    put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/ServerContext/@Id</PATH>";
    put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>200</LENGTH>";
    put '</COLUMN>';
    put '<COLUMN name="servername">';
    put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/ServerContext/@Name</PATH>";
    put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>200</LENGTH>";
    put '</COLUMN>';
    put '</TABLE></SXLEMAP>';
  run;
  libname __mc3 xml xmlfileref=__mc1 xmlmap=__mc2;
  proc append base=&outds data=__mc3.SASContexts;run;
  libname __mc3 clear;
%end;

options metarepository=&repo;

filename __mc1 clear;
filename __mc2 clear;

%mend;