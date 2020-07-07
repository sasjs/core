/**
  @file
  @brief Creates a dataset with all metadata objects for a particular type

  @param type= the metadata type for which to return all objects
  @param outds= the dataset to create that contains the list of types

  @returns outds  dataset containing all objects

  @warning The following filenames are created and then de-assigned:

      filename sxlemap clear;
      filename response clear;
      libname _XML_ clear;

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getobjects(
  type=SASLibrary
  ,outds=work.mm_getobjects
)/*/STORE SOURCE*/;


* use a temporary fileref to hold the response;
filename response temp;
/* get list of libraries */
proc metadata in=
 "<GetMetadataObjects><Reposid>$METAREPOSITORY</Reposid>
   <Type>&type</Type><Objects/><NS>SAS</NS>
   <Flags>0</Flags><Options/></GetMetadataObjects>"
  out=response;
run;

/* write the response to the log for debugging */
data _null_;
  infile response lrecl=1048576;
  input;
  put _infile_;
run;

/* create an XML map to read the response */
filename sxlemap temp;
data _null_;
  file sxlemap;
  put '<SXLEMAP version="1.2" name="SASObjects"><TABLE name="SASObjects">';
  put "<TABLE-PATH syntax='XPath'>/GetMetadataObjects/Objects/&type</TABLE-PATH>";
  put '<COLUMN name="id">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/&type/@Id</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>200</LENGTH>";
  put '</COLUMN><COLUMN name="name">';
  put "<PATH syntax='XPath'>/GetMetadataObjects/Objects/&type/@Name</PATH>";
  put "<TYPE>character</TYPE><DATATYPE>string</DATATYPE><LENGTH>200</LENGTH>";
  put '</COLUMN></TABLE></SXLEMAP>';
run;
libname _XML_ xml xmlfileref=response xmlmap=sxlemap;

proc sort data= _XML_.SASObjects out=&outds;
  by name;
run;

/* clear references */
filename sxlemap clear;
filename response clear;
libname _XML_ clear;

%mend;