/**
  @file
  @brief A macro to delete a directory
  @details Will delete all folder content (including subfolder content) and
    finally, the folder itself.

  @param path Unquoted path to the folder to delete.

  <h4> SAS Macros </h4>
  @li mp_dirlist.sas

**/


%macro mp_deletefolder(path);


%mend mp_deletefolder;