@IsTest
public with sharing class ListigaListorControllerTest {

    static TestQuery incorrectQuery = new TestQuery('SElEcT Id, Name, Phone, Email FROMContact',false, false, '');
    static TestQuery simpleQuery = new TestQuery('SELeCT Id, Name, Phone, Email fROM Contact', true, false, 'Contact');
    static TestQuery mergeIdQuery = new TestQuery('SElECT Id, Name, Phone, Email fROM Contact WHERE AccountId = $record.iD', true, true, 'Contact');
    static TestQuery mergeNameQuery = new TestQuery('sELECT Id, Name, Phone, Email FROm Contact WHERE Account.Name = $record.nAmE',true, true, 'Contact');
    static TestQuery mergeTypeQuery = new TestQuery('SELECt Id, Name, Phone, Email FRoM Contact WHERE Account.tyPe = $record.TypE',true, true, 'Contact');

    static TestQuery[] allTestQueries = new TestQuery[]{incorrectQuery, simpleQuery, mergeIdQuery, mergeNameQuery};

    static List<Contact> createContacts(Integer[] numbOfContacts){
        List<Contact> allContacts = new List<Contact>();
        for(Integer i=0; i<numbOfContacts.size(); i++){
            Account acc = new Account(
            Name = 'Account '+i
        );
        insert acc;
        List<Contact> contacts = new List<Contact>();
        for(Integer j=0; j < numbOfContacts[i]; j++) {
            contacts.add(new Contact(
                FirstName = 'John',
                LastName = 'Doe'+i + j,
                Email = 'john.doe'+i + j+'@testmail.com',
                Phone = String.valueOf(005324+i+j+7+i+j),
                AccountId = acc.Id
            ));
        }
        insert contacts;
        allContacts.addAll(contacts);
        }
        return allContacts;
    }

/*     @IsTest
    static void queryContactRecordsTest() {
        List<Contact> cons = createContacts([10]);
        Id accId = cons[0].AccountId;
        Account acc = [SELECT Id FROM Account WHERE Id = :accId];
        String recordId = acc.id;
        String query = relatedContactsQuery;
        String objetApiName = 'Account';
        String rowActions = 'View, Edit, Delete';
        Integer maxColumns = 5;
        Integer maxRows = 5;
        String columnLabels = 'Col1, Col2, Col3, Col4';
        ListigaListorController.getRecordsByQuery(query, recordId, objetApiName, rowActions, maxColumns, maxRows, columnLabels);

    } */
    @IsTest
    static void getObjectNameTest(){
        for(TestQuery tq : allTestQueries){
            if(tq.validSyntax){
                System.assertEquals(tq.objectName, ListigaListorController.getObjectName(tq.query));
            }
        }
    }
    @IsTest
    static void validateQuerySyntaxTest(){
        for(TestQuery tq : allTestQueries){
            if(!tq.hasMergeField){
                Boolean error = false;
                try{
                    ListigaListorController.validateQuerySyntax(tq.query);
                }catch(ListigaListorController.InvalidInputException ex){
                    error = true;
                }
                System.assertEquals(tq.validSyntax, !error, tq.query);
            }
        }
    }
    @IsTest
    static void getMainRecordTest(){
        String accountId = createContacts(new Integer[]{1})[0].AccountId;
        Account acc = [SELECT Id, Name, Type from Account WHERE Id = :AccountId];

        SObject res = ListigaListorController.getMainRecord(mergeIdQuery.query, accountId, 'Account');
        System.assertEquals(acc.Id, res.Id);
        System.assertEquals(false, res.isSet('Type'), res);

        res = ListigaListorController.getMainRecord(mergeNameQuery.query, accountId, 'Account');
        System.assertEquals(acc.get('Name'), res.get('Name'));
        System.assertEquals(false, res.isSet('Type'), res);

        res = ListigaListorController.getMainRecord(mergeTypeQuery.query, accountId, 'Account');
        System.assertEquals(acc.get('Type'), res.get('Type'), res);

    }
    @IsTest
    static void getParentFieldNameTest(){
        String actual = ListigaListorController.getParentFieldName(mergeIdQuery.query);
        System.assertEquals('', actual);
    }
    class TestQuery {
        String query;
        Boolean validSyntax;
        Boolean hasMergeField;
        String objectName;
        public TestQuery(String query, Boolean validSyntax, Boolean hasMergeField, String objectName){
            this.query = query;
            this.validSyntax = validSyntax;
            this.hasMergeField = hasMergeField;
            this.objectName = objectName;
        }
    }
}