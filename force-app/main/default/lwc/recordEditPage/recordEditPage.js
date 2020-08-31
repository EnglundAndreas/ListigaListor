import { LightningElement, api } from 'lwc';

export default class RecordEditPage extends LightningElement {
   @api recordId;
   @api objectApiName;
   @api recordTypeId;

   @api showPositive;
   @api showNegative;
   @api positiveButtonLabel = 'Save';
   @api negativeButtonLabel = 'Cancel';
   @api showModal;
   @api recordInfo;

   constructor() {
      super();
      this.showNegative = true;
      this.showPositive = true;
      this.showModal = false;
   }

  handlePositive() {
    this.dispatchEvent(new CustomEvent('positive'));
  }

  handleNegative() {
    this.dispatchEvent(new CustomEvent('negative'));
  }

  handleClose() {
    this.dispatchEvent(new CustomEvent('close'));
  }

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