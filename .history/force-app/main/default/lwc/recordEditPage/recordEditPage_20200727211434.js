import { LightningElement, api } from 'lwc';

export default class RecordEditPage extends LightningElement {
    @api recordId;
    @api objectApiName;

    handleSubmit(event){
        event.preventDefault();       // stop the form from submitting
        const fields = event.detail.fields;
        fields.Street = '32 Prince Street';
        this.template.querySelector('lightning-record-edit-form').submit(fields);
     }
     handleSucess(event){
        const updatedRecord = event.detail.id;
        console.log('onsuccess: ', updatedRecord);
     }
}