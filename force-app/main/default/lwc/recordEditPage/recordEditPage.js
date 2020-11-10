import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class RecordEditPage extends LightningElement {
   @api recordId;
   @api parentId;
   @api parentFieldName;
   @api objectApiName;
   @api objectLabel;
   @api recordTypeId;
   @api columns;
   @api header;
   @api showModal;
   @api createMode = false;
   fields;



   connectedCallback() {
      const fields = this.columns.map(column => {
         var fieldName = column['fieldName'];
         if(fieldName) {
            if(fieldName.toLowerCase() != 'id') {
               return {name:fieldName};
            }
         }
      });

      fields.push({name: this.parentFieldName, value: this.parentId});
      
      var containsName = fields.some(field => {
         return JSON.stringify({name: 'Name'}) === JSON.stringify(field);
      });
      var containsId = fields.some(field => {
         return JSON.stringify({name: 'IdLink'}) === JSON.stringify(field);
      })
      if(!containsName && containsId) {
         fields.unshift({name: 'Name'});
      }

      if(this.recordId) {
         this.header = 'Edit Record';
      } else {
         this.header = 'Create New Record';
         this.createMode = true;
      }
      this.fields = fields.filter((field) => { return field });
   }

   handleClose() {
      this.dispatchEvent(new CustomEvent('close'));
   }

   handleSuccess(event){
      console.log('onsuccess: ');
      const evt = new ShowToastEvent({
         title: "Success!",
         message: "The record has been successfully saved.",
         variant: "success",
     });
     this.dispatchEvent(evt);
     this.dispatchEvent(new CustomEvent('success'));
   }

   handleError(event){
      console.log('handleError');
      console.log(JSON.stringify(event.detail));
   }
}