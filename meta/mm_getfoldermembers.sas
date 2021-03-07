/**
  @file
  @brief Returns all direct child members of a particular folder
  @details Displays the children for a particular folder, in a similar fashion
  to the viya counterpart (mv_getfoldermembers.sas)

  Usage:

      %mm_getfoldermembers(root=/, outds=rootfolders)

      %mm_getfoldermembers(root=/User Folders/&sysuserid, outds=usercontent)

  @param [in] root= the parent folder under which to return all contents
  @param [out] outds= the dataset to create that contains the list of directories
  @param [in] mDebug= set to 1 to show debug messages in the log

  <h4> Data Outputs </h4>

  Example for `root=/`:

  |metauri $17|metaname $256|metatype $32|
  |---|---|---|
  |A5XLSNXI.AA000001|Products	|Folder|
  |A5XLSNXI.AA000002|Shared Data	|Folder|
  |A5XLSNXI.AA000003|User Folders	|Folder|
  |A5XLSNXI.AA000004|System	|Folder|
  |A5XLSNXI.AA00003K|30.SASApps	|Folder|
  |A5XLSNXI.AA00006A|Public|Folder|

  <h4> SAS Macros </h4>
  @li mm_getfoldertree.sas
  @li mf_getuniquefileref.sas
  @li mf_getuniquelibref.sas

  @version 9.4
  @author Allan Bowe

**/
%macro mm_getfoldermembers(
     root=
    ,outds=work.mm_getfoldertree
)/*/STORE SOURCE*/;

%if "&root" = "/" %then %do;
  %local fname1 fname2 fname3;
  %let fname1=%mf_getuniquefileref();
  %let fname2=%mf_getuniquefileref();
  %let fname3=%mf_getuniquefileref();
  data _null_ ;
    file &fname1 ;
    put '<GetMetadataObjects>' ;
    put '<Reposid>$METAREPOSITORY</Reposid>' ;
    put '<Type>Tree</Type>' ;
    put '<NS>SAS</NS>' ;
    put '<Flags>388</Flags>' ;
    put '<Options>' ;
    put '<XMLSelect search="Tree[SoftwareComponents/SoftwareComponent'@;
    put '[@Name=''BIP Service'']]"/>';
    put '</Options>' ;
    put '</GetMetadataObjects>' ;
  run ;
  proc metadata in=&fname1 out=&fname2 verbose;run;

  /* create an XML map to read the response */
  data _null_;
    file &fname3;
    put '<SXLEMAP version="1.2" name="SASFolders">';
    put '<TABLE name="SASFolders">';
    put '<TABLE-PATH syntax="XPath">//Objects/Tree</TABLE-PATH>';
    put '<COLUMN name="metauri">><LENGTH>17</LENGTH>';
    put '<PATH syntax="XPath">//Objects/Tree/@Id</PATH></COLUMN>';
    put '<COLUMN name="metaname"><LENGTH>256</LENGTH>>';
    put '<PATH syntax="XPath">//Objects/Tree/@Name</PATH></COLUMN>';
    put '</TABLE></SXLEMAP>';
  run;
  %local libref1;
  %let libref1=%mf_getuniquelibref();
  libname &libref1 xml xmlfileref=&fname2 xmlmap=&fname3;

  data &outds;
    length metatype $32;
    retain metatype 'Folder';
    set &libref1..sasfolders;
  run;

%end;
%else %do;
  %mm_getfoldertree(root=&root, outds=&outds,depth=1)
  data &outds;
    set &outds(rename=(name=metaname publictype=metatype));
    keep metaname metauri metatype;
  run;
%end;

%mend;
