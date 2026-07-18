/**
  @file
  @brief Iterative row-level MD5 hash generator
  @details Generates DATA step statements that compute a deterministic,
    row-level MD5 hash using a Merkle-style construction.  Each variable is
    hashed independently and the resulting raw 16-byte digests are combined
    iteratively.  This avoids concatenating the per-variable hex digests into a
    single SAS character expression, which overflows when datasets contain many
    variables.

    Temporary variables use five leading underscores.

    This macro is called from inside a DATA step.  The caller is responsible
    for declaring the output hash column if it does not already exist on the
    input dataset.

    Variables are hashed in the order supplied.  If a particular variable
    needs to influence the hash first (for example the previous row hash in
    `mp_hashdataset`, or business dates in Data Controller's bitemporal
    loader) simply list it first in `cvars` or `nvars`.

  @param [in] md5_col= Name of the output hash column.
  @param [in] cvars= Space separated list of character variables to hash.
  @param [in] nvars= Space separated list of numeric variables to hash.

  @version 9.3M5
  @author Allan Bowe
**/

%macro mp_rowhash(
    md5_col=
    ,cvars=
    ,nvars=
  );

  /* DATA step temp variables use five leading underscores.  The names
      are generated at macro invocation to avoid clashing with data columns. */
  %local state digest pair numtext normal i chars nums;
  %let state=%mf_getuniquename(prefix=_____state_);
  %let digest=%mf_getuniquename(prefix=_____digest_);
  %let pair=%mf_getuniquename(prefix=_____pair_);
  %let numtext=%mf_getuniquename(prefix=_____numtext_);
  %let normal=%mf_getuniquename(prefix=_____normal_);
  %let i=%mf_getuniquename(prefix=_____i_);
  %let chars=%mf_getuniquename(prefix=_____chars_);
  %let nums=%mf_getuniquename(prefix=_____nums_);

  length &state $16
        &digest $16
        &pair $32
        &numtext $64
        &normal &i 8;
  if _n_=1 then call missing(&state,&digest,&pair,&numtext,&normal,&i);
  drop &state &digest &pair &numtext &normal &i;

  /* Versioned seed prevents confusion with other hashing schemes. */
  &state = md5('DC HASH v2');

  %if %length(&cvars)>0 %then %do;
    array &chars{*} $ &cvars;
    do &i = 1 to dim(&chars);
      /* Leading blanks are retained. */
      &digest = md5(trimn(&chars[&i]));
      substr(&pair,  1, 16) = &state;
      substr(&pair, 17, 16) = &digest;
      &state = md5(&pair);
    end;
  %end;

  %if %length(&nvars)>0 %then %do;
    array &nums{*} &nvars;
    do &i = 1 to dim(&nums);
      /*
        multiply-by-one for consistent cross-system precision.
        Ignore null to protect SAS special missing values.
      */
      &normal = ifn(
        missing(&nums[&i]),
        &nums[&i],
        &nums[&i] * 1
      );
      &numtext = put(&normal, binary64.);
      &digest = md5(trim(&numtext));
      substr(&pair,  1, 16) = &state;
      substr(&pair, 17, 16) = &digest;
      &state = md5(&pair);
    end;
  %end;

  &md5_col = put(&state, $hex32.);

%mend mp_rowhash;
