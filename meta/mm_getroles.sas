/**
  @file mm_getroles.sas
  @brief Creates a table containing a list of roles
  @details

  Usage:

      %mm_getroles()

  @param [out] outds the dataset to create that contains the list of roles

  @returns outds  dataset containing all roles, with the following columns:
    - uri
    - name

  @warning The following filenames are created and then de-assigned:

      filename sxlemap clear;
      filename response clear;
      libname _XML_ clear;

  @version 9.3
  @author Allan Bowe

**/

%macro mm_getroles(
    outds=work.mm_getroles
)/*/STORE SOURCE*/;

filename response temp;
options noquotelenmax;
proc metadata in= '<GetMetadataObjects><Reposid>$METAREPOSITORY</Reposid>
 <Type>IdentityGroup</Type><NS>SAS</NS><Flags>388</Flags>
 <Options>
 <Templates><IdentityGroup Name="" Desc="" PublicType=""/></Templates>
 <XMLSelect search="@PublicType=''Role''"/>
 </Options>
 </GetMetadataObjects>'
  out=response;
run;

filename sxlemap temp;
data _null_;
  file sxlemap;
  put '<SXLEMAP version="1.2" name="roles"><TABLE name="roles">';
  put "<TABLE-PATH syntax='XPath'>/GetMetadataObjects/Objects/IdentityGroup</TABLE-PATH>";
  put '<COLUMN name="roleuri">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/IdentityGroup/@Id</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>32</LENGTH>";
  put '</COLUMN><COLUMN name="rolename">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/IdentityGroup/@Name</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>256</LENGTH>";
  put '</COLUMN><COLUMN name="roledesc">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/IdentityGroup/@Desc</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>500</LENGTH>";
  put '</COLUMN></TABLE></SXLEMAP>';
run;
libname _XML_ xml xmlfileref=response xmlmap=sxlemap;

proc sort data= _XML_.roles out=&outds;
  by rolename;
run;

filename sxlemap clear;
filename response clear;
libname _XML_ clear;

%mend;
