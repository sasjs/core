/**
  @file
  @brief Returns a userid according to session context
  @details In a workspace session, a user is generally represented by <code>
    &sysuserid</code> or <code>SYS_COMPUTE_SESSION_OWNER</code> if it exists.
    In a Stored Process session, <code>&sysuserid</code>
    resolves to a system account (default=sassrv) and instead there are several
    metadata username variables to choose from (_metauser, _metaperson
    ,_username, _secureusername).  The OS account is represented by
    <code> _secureusername</code> whilst the metadata account is under <code>
    _metaperson</code>.

        %let user= %mf_getUser();
        %put &user;

  @return SYSUSERID (if workspace server)
  @return _METAPERSON (if stored process server)
  @return SYS_COMPUTE_SESSION_OWNER (if Viya compute session)

  @version 9.2
  @author Allan Bowe
**/

%macro mf_getuser(
)/*/STORE SOURCE*/;
  %local user;

  %if %symexist(_sasjs_username) %then %let user=&_sasjs_username;
  %else %if %symexist(SYS_COMPUTE_SESSION_OWNER) %then %do;
    %let user=&SYS_COMPUTE_SESSION_OWNER;
  %end;
  %else %if %symexist(_metaperson) %then %do;
    %if %length(&_metaperson)=0 %then %let user=&sysuserid;
    /* sometimes SAS will add @domain extension - remove for consistency */
    /* but be sure to quote in case of usernames with commas */
    %else %let user=%unquote(%scan(%quote(&_metaperson),1,@));
  %end;
  %else %let user=&sysuserid;

  %quote(&user)

%mend mf_getuser;
