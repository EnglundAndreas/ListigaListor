import { LightningElement, api } from 'lwc';

export default class RecordEditPage extends LightningElement {
   @api recordId;
   @api objectApiName;
   @api recordTypeId;
   @api columns;
   @api header;
   @api showPositive;
   @api showNegative;
   @api showModal;
   @api recordInfo;

   fields;

   constructor() {
      super();
      console.log('recordEdit Page constructor');
      this.showNegative = true;
      this.showPositive = true;
      this.showModal = false;
   }

   connectedCallback() {
      console.log('connected Callback run');
      console.log(JSON.stringify(this.recordInfo));
      console.log(this.recordId);
      console.log(JSON.stringify(this.columns));
      this.header = this.recordInfo['Name'];
      const fields = this.columns.map(column => {
         var fieldName = column['fieldName'];
         if(fieldName) {
            if(fieldName.toLowerCase() == 'id') {
               return {name:'Name', value:this.recordInfo['IdLabel']};
            }
            return {name:fieldName, value:this.recordInfo[fieldName]};
         }
      });
      this.fields = fields.filter((field) => { return field });
      console.log('<< fields transformed '+ JSON.stringify(this.fields));
   }

   // handlePositive() {
   //    this.dispatchEvent(new CustomEvent('positive'));
   // }

   // handleNegative() {
   //    this.dispatchEvent(new CustomEvent('negative'));
   // }

   handleClose() {
      this.dispatchEvent(new CustomEvent('close'));
   }

   handleSubmit(event){
      event.preventDefault();
      console.log('handle submit', JSON.stringify(event));
      const fields = event.detail.fields;
      console.log(fields);
      this.template.querySelector('lightning-record-edit-form').submit(fields);
   }
   handleSucess(event){
      const updatedRecord = event.detail.id;
      console.log('onsuccess: ', updatedRecord);
   }
}