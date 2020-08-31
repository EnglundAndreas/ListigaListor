public with sharing class dynamicRowsController {
        
    @AuraEnabled
    public static void saveAccountsLwc(List<account> records){
        if(records.size()>0 && records != null){
            List<account> accs = new List<account>();
            
            for(integer i = 0; i < records.size(); i++) {
                account acc = new account();
                acc.Id = records[i].Id;
                acc.Industry = 'Energy';
                acc.Name = records[i].Name;
                acc.JobType__c = records[i].JobType__c;
                acc.Controlling_Picklist__c = records[i].Controlling_Picklist__c;
                acc.Dependent_Picklist__c = records[i].Dependent_Picklist__c;
                acc.Customer__c = records[i].Customer__c;
                accs.add(acc);
            }
            
            upsert accs;
        }
    }
    
    @AuraEnabled
    public static List<Account> getAccounts(){
        return [SELECT Id, Name, Industry, accountrich__c, Master_Picklist__c, Controlling_Picklist__c, Dependent_Picklist__c, JobType__c, JobType__r.Name, Customer__c 
                from ACCOUNT 
                Where Industry = 'Energy' AND createdDate != NULL ORDER BY createdDate DESC LIMIT 10];
    }
    
    @AuraEnabled
    public static String deleteAccounts(String toDeleteId){
        List<account> acc = new List<Account>();
        Account a = new Account();
        a.Id = toDeleteId;
        acc.add(a);
        Database.DeleteResult[] drList = Database.delete(acc, false);
		List<String> deletedIds = new List<String>();
        List<String> errorMessages = new List<String>();
        // Iterate through each returned result
        for(Database.DeleteResult dr : drList) {
            if (dr.isSuccess()) {
                // Operation was successful, so get the ID of the record that was processed
                System.debug('Successfully deleted account with ID: ' + dr.getId());
                deletedIds.add(dr.getId());
                
            }
            else {
                // Operation failed, so get all errors                
                for(Database.Error err : dr.getErrors()) {
                    System.debug('The following error has occurred.');                    
                    System.debug(err.getStatusCode() + ': ' + err.getMessage());
                    System.debug('Account fields that affected this error: ' + err.getFields());
                    errorMessages.add(err.getMessage());
                }
                
            }
        }
        if(deletedIds.size() > 0)
            return 'success';
        else
            return errorMessages[0];
    }
    
}