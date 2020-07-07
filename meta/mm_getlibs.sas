/**
  @file
  @brief Creates a dataset with all metadata libraries
  @details Will only show the libraries to which a user has the requisite
    metadata access.

  @param outds the dataset to create that contains the list of libraries
  @param mDebug set to anything but * or 0 to show debug messages in the log

  @returns outds  dataset containing all groups in a column named "metagroup"
    (defaults to work.mm_getlibs). The following columns are provided:
    - LibraryId
    - LibraryName
    - LibraryRef
    - Engine

  @warning The following filenames are created and then de-assigned:

      filename sxlemap clear;
      filename response clear;
      libname _XML_ clear;

  @version 9.2
  @author Allan Bowe

**/

%macro mm_getlibs(
    outds=work.mm_getLibs
)/*/STORE SOURCE*/;

/*
  flags:

  OMI_SUCCINCT     (2048) Do not return attributes with null values.
  OMI_GET_METADATA (256)  Executes a GetMetadata call for each object that
                          is returned by the GetMetadataObjects method.
  OMI_ALL_SIMPLE   (8)    Gets all of the attributes of the requested object.
*/
data _null_;
  flags=2048+256+8;
  call symputx('flags',flags,'l');
run;

* use a temporary fileref to hold the response;
filename response temp;
/* get list of libraries */
proc metadata in=
 '<GetMetadataObjects>
  <Reposid>$METAREPOSITORY</Reposid>
  <Type>SASLibrary</Type>
  <Objects/>
  <NS>SAS</NS>
  <Flags>&flags</Flags>
  <Options/>
  </GetMetadataObjects>'
  out=response;
run;

/* write the response to the log for debugging */
data _null_;
  infile response lrecl=32767;
  input;
  put _infile_;
run;

/* create an XML map to read the response */
filename sxlemap temp;
data _null_;
  file sxlemap;
  put '<SXLEMAP version="1.2" name="SASLibrary">';
  put '<TABLE name="SASLibrary">';
  put '<TABLE-PATH syntax="XPath">//Objects/SASLibrary</TABLE-PATH>';
  put '<COLUMN name="LibraryId">><LENGTH>17</LENGTH>';
  put '<PATH syntax="XPath">//Objects/SASLibrary/@Id</PATH></COLUMN>';
  put '<COLUMN name="LibraryName"><LENGTH>256</LENGTH>>';
  put '<PATH syntax="XPath">//Objects/SASLibrary/@Name</PATH></COLUMN>';
  put '<COLUMN name="LibraryRef"><LENGTH>8</LENGTH>';
  put '<PATH syntax="XPath">//Objects/SASLibrary/@Libref</PATH></COLUMN>';
  put '<COLUMN name="Engine">><LENGTH>12</LENGTH>';
  put '<PATH syntax="XPath">//Objects/SASLibrary/@Engine</PATH></COLUMN>';
  put '</TABLE></SXLEMAP>';
run;
libname _XML_ xml xmlfileref=response xmlmap=sxlemap;

/* sort the response by library name */
proc sort data=_XML_.saslibrary out=&outds;
  by libraryname;
run;


/* clear references */
filename sxlemap clear;
filename response clear;
libname _XML_ clear;

%mend;