import { LightningElement, api } from 'lwc';

export default class RecordEditPage extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api recordTypeId;

    handleSubmit(event){
        event.preventDefault();     
        const fields = event.detail.fields;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
     }
     handleSucess(event){
        const updatedRecord = event.detail.id;
        console.log('onsuccess: ', updatedRecord);
     }
}