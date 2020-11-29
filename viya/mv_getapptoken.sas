 /**
   @file
   @brief deprecated - replaced by mv_registerclient.sas

   @version VIYA V.03.04
   @author Allan Bowe, source: https://github.com/sasjs/core

   <h4> Dependencies </h4>
   @li mv_registerclient.sas

 **/

 %macro mv_getapptoken(client_id=someclient
     ,client_secret=somesecret
     ,grant_type=authorization_code
   );

%mv_registerclient(client_id=&client_id
  ,client_secret=&client_secret
  ,grant_type=&grant_type
)

%mend;