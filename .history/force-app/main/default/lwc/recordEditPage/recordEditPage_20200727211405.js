import { LightningElement, api } from 'lwc';

export default class RecordEditPage extends LightningElement {
    @api recordId;
    @api objectApiName;
}