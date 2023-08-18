/**
  @file
  @brief Abort, ungracefully
  @details Will abort with a straightforward %abort if the condition is true.

  @param [in] mac= (mf_abort.sas) Name of calling macro (is printed to the log)
  @param [in] msg= ( ) Additional string to print to the log
  @param [in] iftrue= (%str(1=1)) Conditional logic under which to perform the
    abort

  <h4> Related Macros </h4>
  @li mp_abort.sas

  @version 9.2
  @author Allan Bowe
  @cond
**/

%macro mf_abort(mac=mf_abort.sas, msg=, iftrue=%str(1=1)
)/des='ungraceful abort' /*STORE SOURCE*/;

  %if not(%eval(%unquote(&iftrue))) %then %return;

  %put NOTE: ///  mf_abort macro executing //;
  %if %length(&mac)>0 %then %put NOTE- called by &mac;
  %put NOTE - &msg;

  %abort;

%mend mf_abort;

/** @endcond */
