// This file is generated as an Apex representation of the
//     corresponding sObject and its fields.
// This read-only file is used by the Apex Language Server to
//     provide code smartness, and is deleted each time you
//     refresh your sObject definitions.
// To edit your sObjects and their fields, edit the corresponding
//     .object-meta.xml and .field-meta.xml files.

global class Location {
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
    global String LocationType;
    global Double Latitude;
    global Double Longitude;
    global Location Location;
    global String Description;
    global String DrivingDirections;
    global String TimeZone;
    global Location ParentLocation;
    global Id ParentLocationId;
    global Date PossessionDate;
    global Date ConstructionStartDate;
    global Date ConstructionEndDate;
    global Date OpenDate;
    global Date CloseDate;
    global Date RemodelStartDate;
    global Date RemodelEndDate;
    global Boolean IsMobile;
    global Boolean IsInventoryLocation;
    global Address VisitorAddress;
    global Id VisitorAddressId;
    global Location RootLocation;
    global Id RootLocationId;
    global Integer LocationLevel;
    global List<Address> Addresses;
    global List<AssociatedLocation> AssociatedLocations;
    global List<AttachedContentDocument> AttachedContentDocuments;
    global List<CombinedAttachment> CombinedAttachments;
    global List<ContentDocumentLink> ContentDocumentLinks;
    global List<Location> ChildLocations;
    global List<LocationHistory> Histories;
    global List<ProcessInstance> ProcessInstances;
    global List<ProcessInstanceHistory> ProcessSteps;
    global List<RecordAction> RecordActions;
    global List<RecordActionHistory> RecordActionHistories;
    global List<ContentVersion> FirstPublishLocation;
    global List<FlowRecordRelation> RelatedRecord;
    global List<Location> RootLocation;

    global Location () 
    {
    }
}