@isTest
public with sharing class CustomLookupControllerTest {


    @isTest
    private static void getAllAccount(){
        List<Account> accountsInSystem = [SELECT Id, Name FROM Account];
        System.assertEquals(2, accountsInSystem.size());

        Test.startTest();
            List<Sobject> results = CustomLookupController.lookUp('', 'Account', '', '', 'Id, Name');
            System.assertEquals(2, results.size());
        Test.stopTest();

    }

    @isTest
    private static void searchAccountWithKeyword(){
        List<Account> accountsInSystem = [SELECT Id, Name FROM Account];
        System.assertEquals(2, accountsInSystem.size());

        Test.startTest();
            List<Sobject> results = CustomLookupController.lookUp('Test', 'Account', '', '', 'Id, Name');
            System.assertEquals(1, results.size());
            System.assertEquals('Test Account', results[0].get('Name'));
        Test.stopTest();
    }

    @isTest
    private static void searchAccountWithId(){
        List<Account> accountsInSystem = [SELECT Id, Name FROM Account];
        System.assertEquals(2, accountsInSystem.size());

        Test.startTest();
            List<Sobject> results = CustomLookupController.lookUp('', 'Account', '', accountsInSystem[0].Id, 'Id, Name');
            System.assertEquals(1, results.size());
            System.assertEquals(accountsInSystem[0].Id, results[0].get('Id'));
        Test.stopTest();
    }

    @isTest
    private static void searchAccountWithFilters(){
        List<Account> accountsInSystem = [SELECT Id, Name FROM Account];
        System.assertEquals(2, accountsInSystem.size());

        Test.startTest();
            String filters = 'Name = \'Test Account\'';
            List<Sobject> results = CustomLookupController.lookUp('', 'Account', filters , '', 'Id, Name');
            System.assertEquals(1, results.size());
            System.assertEquals('Test Account', results[0].get('Name'));
        Test.stopTest();
    }

    @testSetup
    private static void setupDate(){
        //generate two accounts with basic information
        List<Account> accountsToBeInserted = new List<Account>();
        accountsToBeInserted.add(new Account(Name = 'Search Account'));
        accountsToBeInserted.add(new Account(Name = 'Test Account'));
        insert accountsToBeInserted;
    }
}