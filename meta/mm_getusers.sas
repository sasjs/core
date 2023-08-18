/**
  @file mm_getusers.sas
  @brief Creates a table containing a list of all users
  @details Only shows a limited number of attributes as some sites will have a
  LOT of users.

  Usage:

      %mm_getusers()

  Optionally, filter for a user (useful to get the uri):

      %mm_getusers(user=&_metaperson)

  @returns outds  dataset containing all users, with the following columns:
    - uri
    - name

  @param [in] user= (0) Set to a metadata user to filter on that user
  @param [out] outds= (work.mm_getusers) The output table to create

  @version 9.3
  @author Allan Bowe

**/

%macro mm_getusers(
    outds=work.mm_getusers,
    user=0
)/*/STORE SOURCE*/;

filename response temp;
%if %superq(user)=0 %then %do;
  proc metadata in= '<GetMetadataObjects>
    <Reposid>$METAREPOSITORY</Reposid>
    <Type>Person</Type>
    <NS>SAS</NS>
    <Flags>0</Flags>
    <Options>
    <Templates>
    <Person Name=""/>
    </Templates>
    </Options>
    </GetMetadataObjects>'
    out=response;
  run;
%end;
%else %do;
  filename inref temp;
  data _null_;
    file inref;
    put "<GetMetadataObjects>";
    put "<Reposid>$METAREPOSITORY</Reposid>";
    put "<Type>Person</Type>";
    put "<NS>SAS</NS>";
    put "<!-- Specify the OMI_XMLSELECT (128) flag  -->";
    put "<Flags>128</Flags>";
    put "<Options>";
    put "<Templates>";
    put '<Person Name=""/>';
    put "</Templates>";
    length string $10000;
    string=cats('<XMLSELECT search="Person[@Name=',"'&user'",']"/>');
    put string;
    put "</Options>";
    put "</GetMetadataObjects>";
  run;
  proc metadata in=inref out=response;
  run;
%end;

filename sxlemap temp;
data _null_;
  file sxlemap;
  put '<SXLEMAP version="1.2" name="SASObjects"><TABLE name="SASObjects">';
  put "<TABLE-PATH syntax='XPath'>/GetMetadataObjects/Objects/Person";
  put "</TABLE-PATH>";
  put '<COLUMN name="uri">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/Person/@Id</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>32</LENGTH>";
  put '</COLUMN><COLUMN name="name">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/Person/@Name</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>256</LENGTH>";
  put '</COLUMN></TABLE></SXLEMAP>';
run;
libname _XML_ xml xmlfileref=response xmlmap=sxlemap;

proc sort data= _XML_.SASObjects out=&outds;
  by name;
run;

filename sxlemap clear;
filename response clear;
libname _XML_ clear;

%mend mm_getusers;
