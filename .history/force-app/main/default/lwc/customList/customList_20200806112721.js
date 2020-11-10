import { LightningElement, track } from 'lwc';
import saveAccountsLwc from '@salesforce/apex/dynamicRowsController.saveAccountsLwc';
import getAccounts from '@salesforce/apex/dynamicRowsController.getAccounts';
import deleteAccounts from '@salesforce/apex/dynamicRowsController.deleteAccounts';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class CustomList extends LightningElement {
    @track isEdited = false;
    @track toggleSaveLabel = 'Save';
    @track myList = [{Name : "Kishore", JobType__c : "Birlasoft", key : Math.random().toString(36).substring(2, 15)},
                     {Name : "Suresh", JobType__c : "TCS",  key : Math.random().toString(36).substring(2, 15)}];

    /*--------------------Mapping field values to the list onchange START --------------------*/                
    handleNameChange(event) {
        let element = this.myList.find(ele  => ele.Id === event.target.dataset.id);
        element.Name = event.target.value;
        this.myList = [...this.myList];
        console.log(JSON.stringify(this.myList));
    }

    handlePicklistChange(event) {
        let eventData = event.detail;
        let pickValue = event.detail.selectedValue;
        let uniqueKey = event.detail.key;

        let element = this.myList.find(ele  => ele.Id === uniqueKey);
        element.Controlling_Picklist__c = pickValue;
        this.myList = [...this.myList];
    }

    handleDependentPicklistChange(event) {
        let eventData = event.detail;
        let pickValue = event.detail.selectedValue;
        let uniqueKey = event.detail.key;

        let element = this.myList.find(ele  => ele.Id === uniqueKey);
        element.Dependent_Picklist__c = pickValue;
        this.myList = [...this.myList];
    }

    handleSelection(event) {
        let eventData = event.detail;
        let id = event.detail.selectedId;
        let uniqueKey = event.detail.key;
       
        let element = this.myList.find(ele  => ele.Id === uniqueKey);
        element.JobType__c = id;
        this.myList = [...this.myList];
    }
    /*--------------------Mapping field values to the list onchange END --------------------*/    

    add() {
        let newList = this.myList;
        newList.push({Name : "", JobType__c : "",  key : Math.random().toString(36).substring(2, 15)});
        this.myList = newList;
    }

    remove(event) { 
        let indexPosition = event.currentTarget.name;
        const recId = event.currentTarget.dataset.id;
                
        deleteAccounts({toDeleteId : recId})
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title : 'Success',
                    message : `Record deleted succesfully!`,
                    variant : 'success',
                }),
            )
            if(this.myList.length > 1) 
            this.myList.splice(indexPosition, 1);
            this.error = undefined;
        })
        .catch(error => {
            this.error = error;
        })
    }

    handleSave() {
        this.toggleSaveLabel = 'Saving...'
        let toSaveList = this.myList;
        toSaveList.forEach((element, index) => {
            if(element.Name === ''){
                toSaveList.splice(index, 1);
            }
        });

        this.myList = toSaveList;
        saveAccountsLwc({records : toSaveList})
        .then(() => {
            this.toggleSaveLabel = 'Saved';
            
            this.dispatchEvent(
                new ShowToastEvent({
                    title : 'Success',
                    message : `Records saved succesfully!`,
                    variant : 'success',
                }),
            )
            this.getAccountRecords();
            this.isEdited = false;
            this.error = undefined;
        })
        .catch(error => {
            this.error = error;
            this.record = undefined;
            console.log("Error in Save call back:", this.error);
        })
        .finally(() => {
            setTimeout(() => {
                this.toggleSaveLabel = 'Save';
            }, 3000);
        });
    }

    connectedCallback() {
        this.getAccountRecords();
    }

    getAccountRecords() {
        getAccounts()
            .then(result => {
                this.record = result;
                for(let i = 0; i < this.record.length; i++) {
                    if(this.record[i].JobType__c) {
                        this.record[i].JobTypeName = this.record[i].JobType__r.Name;
                        this.record[i].JobTypeUrl = `/${this.record[i].JobType__r.Id}`;
                    }
                    if(this.record[i].Id)
                    this.record[i].recordUrl = `/${this.record[i].Id}`;
                }
                this.myList = this.record;
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
                this.record = undefined;
            });
    }

    onDoubleClickEdit() {
        this.isEdited = true;
    }

    handleCancel() {
        this.isEdited = false;
    }
}