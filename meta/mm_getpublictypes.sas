/**
  @file mm_getpublictypes.sas
  @brief Creates a dataset with all deployable public types
  @details More info:
  https://support.sas.com/documentation/cdl/en/bisag/65422/HTML/default/viewer.htm#n1nkrdzsq5iunln18bk2236istkb.htm

  Usage:

        * dataset will contain one column - publictype ($64);
        %mm_getpublictypes(outds=types)

  @returns outds= dataset containing all types

  @version 9.3
  @author Allan Bowe

**/

%macro mm_getpublictypes(
    outds=work.mm_getpublictypes
)/*/STORE SOURCE*/;

proc sql;
create table &outds (publictype char(64)); /* longest is currently 52 */
insert into &outds values ('ACT');
insert into &outds values ('Action');
insert into &outds values ('Application');
insert into &outds values ('ApplicationServer');
insert into &outds values ('BurstDefinition');
insert into &outds values ('Channel');
insert into &outds values ('Condition');
insert into &outds values ('ConditionActionSet');
insert into &outds values ('ContentSubscriber');
insert into &outds values ('Cube');
insert into &outds values ('DataExploration');
insert into &outds values ('DeployedFlow');
insert into &outds values ('DeployedJob');
insert into &outds values ('Document');
insert into &outds values ('EventSubscriber');
insert into &outds values ('ExternalFile');
insert into &outds values ('FavoritesFolder');
insert into &outds values ('Folder');
insert into &outds values ('Folder.SecuredData');
insert into &outds values ('GeneratedTransform');
insert into &outds values ('InformationMap');
insert into &outds values ('InformationMap.OLAP');
insert into &outds values ('InformationMap.Relational');
insert into &outds values ('JMSDestination (Java Messaging System message queue)');
insert into &outds values ('Job');
insert into &outds values ('Job.Cube');
insert into &outds values ('Library');
insert into &outds values ('MessageQueue');
insert into &outds values ('MiningResults');
insert into &outds values ('MQM.JMS (queue manager for Java Messaging Service)');
insert into &outds values ('MQM.MSMQ (queue manager for MSMQ)');
insert into &outds values ('MQM.Websphere (queue manager for WebSphere MQ)');
insert into &outds values ('Note');
insert into &outds values ('OLAPSchema');
insert into &outds values ('Project');
insert into &outds values ('Project.EG');
insert into &outds values ('Project.AMOExcel');
insert into &outds values ('Project.AMOPowerPoint');
insert into &outds values ('Project.AMOWord');
insert into &outds values ('Prompt');
insert into &outds values ('PromptGroup');
insert into &outds values ('Report');
insert into &outds values ('Report.Component');
insert into &outds values ('Report.Image');
insert into &outds values ('Report.StoredProcess');
insert into &outds values ('Role');
insert into &outds values ('SearchFolder');
insert into &outds values ('SecuredLibrary');
insert into &outds values ('Server');
insert into &outds values ('Service.SoapGenerated');
insert into &outds values ('SharedDimension');
insert into &outds values ('Spawner.Connect');
insert into &outds values ('Spawner.IOM (object spawner)');
insert into &outds values ('StoredProcess');
insert into &outds values ('SubscriberGroup.Content');
insert into &outds values ('SubscriberGroup.Event');
insert into &outds values ('Table');
insert into &outds values ('User');
insert into &outds values ('UserGroup');
quit;

%mend;