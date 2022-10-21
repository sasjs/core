/**
  @file
  @brief Deploy repo as a SAS PACKAGES module
  @details After every release, this program is executed to update the SASPAC
    repo with the latest macros (and same version number).
    The program is first compiled using sasjs compile, then executed using
    sasjs run.

    Requires the server to have SSH keys.

  <h4> SAS Macros </h4>
  @li mp_gitadd.sas
  @li mp_gitreleaseinfo.sas
  @li mp_gitstatus.sas

**/


/* get package version */
%mp_gitreleaseinfo(GITHUB,sasjs/core,outlib=splib)
data _null_;
  set splib.root;
  call symputx('version',substr(TAG_NAME,2));
run;

/* clone the source repo */
%let dir = %sysfunc(pathname(work))/core;
%put source clone rc=%sysfunc(GITFN_CLONE(https://github.com/sasjs/core,&dir));


/*
  clone the target repo.
  If you have issues, see: https://stackoverflow.com/questions/74082874
*/
options dlcreatedir;
libname _ "&dirOut.";
%let dirOut = %sysfunc(pathname(work))/package;
%put tgt clone rc=%sysfunc(GITFN_CLONE(
  git@github.com:SASPAC/sasjscore.git,
  &dirOut,
  git,
  %str( ),
  /home/sasjssrv/.ssh/id_ecdsa.pub,
  /home/sasjssrv/.ssh/id_ecdsa
));


/*
  Prepare Package Metadata
*/
data _null_;
  infile CARDS4;
  file  "&dirOut./description.sas";
  input;
  if _infile_ =: 'Version:' then put "Version: &version.";
                            else put _infile_;
CARDS4;
Type: Package
Package: SASjsCore
Title: SAS Macros for Application Development
Version: $(PLACEHOLDER)
Author: Allan Bowe
Maintainer: 4GL Ltd
License: MIT
Encoding: UTF8

DESCRIPTION START:

The SASjs Macro Core library is a component of the SASjs framework, the
source for which is avaible here: https://github.com/sasjs

Macros are divided by:

* Macro Functions (prefix mf_)
* Macro Procedures (prefix mp_)
* Macros for Metadata (prefix mm_)
* Macros for SASjs Server (prefix ms_)
* Macros for Viya (prefix mv_)

DESCRIPTION END:
;;;;
run;

/*
  Prepare Package License
*/
data _null_;
  file  "&dirOut./license.sas";
  infile "&dir/LICENSE";
  input;
  put _infile_;
run;

/*
  Extract Core files into MacroCore Package location
*/
data members(compress=char);
  length dref dref2 $ 8 name name2 $ 32 path $ 2048;
  rc = filename(dref, "&dir.");
  put dref=;
  did = dopen(dref);
  if did then
    do i = 1 to dnum(did);
      name = dread(did, i);
      if name in
        ("base" "ddl" "fcmp" "lua" "meta" "metax" "server" "viya" "xplatform")
      then do;
          rc = filename(dref2,catx("/", "&dir.", name));
          put dref2= name;
          did2 = dopen(dref2);

          if did2 then
            do j = 1 to dnum(did2);
              name2 = dread(did2, j);
              path = catx("/", "&dir.", name, name2);
              if "sas" = scan(name2, -1, ".") then output;
            end;
          rc = dclose(did2);
          rc = filename(dref2);
        end;
    end;
  rc = dclose(did);
  rc = filename(dref);
  keep name name2 path;
run;

%let temp_options = %sysfunc(getoption(source)) %sysfunc(getoption(notes));
options nosource nonotes;
data _null_;
  set members;
  by name notsorted;

  ord + first.name;

  if first.name then
    do;
      call execute('libname _ '
        !! quote(catx("/", "&dirOut.", put(ord, z3.)!!"_macros"))
        !! ";"
      );
      put @1 "./" ord z3. "_macros/";
    end;

  put @10 name2;
  call execute("
  data _null_;
    infile " !! quote(strip(path)) !! ";
    file " !! quote(catx("/", "&dirOut.", put(ord, z3.)!!"_macros", name2)) !!";
    input;
    select;
      when (2 = trigger) put _infile_;
      when (_infile_ = '/**') do; put '/*** HELP START ***//**'; trigger+1; end;
      when (_infile_ = '**/') do; put '**//*** HELP END ***/';   trigger+1; end;
      otherwise put _infile_;
    end;
  run;");

run;
options &temp_options.;

/*
  Generate SASjsCore Package
*/
%GeneratePackage(
  filesLocation=&dirOut
)

/**
  * apply new version in a github action
  * 1. create folder
  * 2. create template yaml
  * 3. replace version number
  */

%mf_mkdir(&dirout/.github/workflows)

%let desc=Version &version of sasjs/core is now on SAS PACKAGES :ok_hand:;
data _null_;
  file "&dirout/.github/workflows/release.yml";
  put "name: SASjs Core Package Publish Tag";
  put "on:";
  put "  push:";
  put "    branches:";
  put "      - main";
  put "jobs:";
  put "  update:";
  put "    runs-on: ubuntu-latest";
  put "    steps:";
  put "      - uses: actions/checkout@master";
  put "      - name: Make Release";
  put "        uses: alice-biometrics/release-creator/@v1.0.5";
  put "        with:";
  put "          github_token: ${{ secrets.GH_TOKEN }}";
  put "          branch: main";
  put "          draft: false";
  put "          version: &version";
  put "          description: '&desc'";
run;


/**
  * Add, Commit & Push!
  */
%mp_gitstatus(&dirout,outds=work.gitstatus,mdebug=1)
%mp_gitadd(&dirout,inds=work.gitstatus,mdebug=1)

data _null_;
  rc=gitfn_commit("&dirout"
    ,"HEAD","&sysuserid","sasjs@core"
    ,"FEAT: Releasing &version"
  );
  put rc=;
  rc=git_push(
    "&dirout"
    ,"git"
    ,""
    ,"/home/sasjssrv/.ssh/id_ecdsa.pub"
    ,"/home/sasjssrv/.ssh/id_ecdsa"
  );
run;




