// This file is generated as an Apex representation of the
//     corresponding sObject and its fields.
// This read-only file is used by the Apex Language Server to
//     provide code smartness, and is deleted each time you
//     refresh your sObject definitions.
// To edit your sObjects and their fields, edit the corresponding
//     .object-meta.xml and .field-meta.xml files.

global class SOSSession {
    global Id Id;
    global SObject Owner;
    global Id OwnerId;
    global Boolean IsDeleted;
    global String Name;
    global Datetime CreatedDate;
    global User CreatedBy;
    global Id CreatedById;
    global Datetime LastModifiedDate;
    global User LastModifiedBy;
    global Id LastModifiedById;
    global Datetime SystemModstamp;
    global Datetime LastViewedDate;
    global Datetime LastReferencedDate;
    global SOSDeployment Deployment;
    global Id DeploymentId;
    global String SessionToken;
    global Contact Contact;
    global Id ContactId;
    global Case Case;
    global Id CaseId;
    global Datetime StartTime;
    global Datetime EndTime;
    global String SessionRecordingUrl;
    global String SystemInfo;
    global String SosVersion;
    global String AppVersion;
    global String IpAddress;
    global String OpentokSession;
    global Integer SessionDuration;
    global Integer WaitDuration;
    global List<ActivityHistory> ActivityHistories;
    global List<AttachedContentDocument> AttachedContentDocuments;
    global List<CombinedAttachment> CombinedAttachments;
    global List<ContentDocumentLink> ContentDocumentLinks;
    global List<EmailMessage> Emails;
    global List<Event> Events;
    global List<OpenActivity> OpenActivities;
    global List<SOSSessionActivity> SOSSessionActivities;
    global List<SOSSessionHistory> Histories;
    global List<Task> Tasks;
    global List<ContentVersion> FirstPublishLocation;
    global List<EventChangeEvent> What;
    global List<EventRelationChangeEvent> Relation;
    global List<FlowRecordRelation> RelatedRecord;
    global List<OutgoingEmail> RelatedTo;
    global List<TaskChangeEvent> What;

    global SOSSession () 
    {
    }
}