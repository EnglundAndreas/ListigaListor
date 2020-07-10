import { LightningElement, wire, api, track } from 'lwc';
import getRecords from '@salesforce/apex/ListigaListorController.getRecords';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';

export default class ListigLista extends LightningElement {
    @api objectName;
    @api recordId;
    @api strTitle;
    @api filter;
    @api parentFieldName;
    @track columns;

    @wire(getRecords, {objectName: '$objectName', fieldNames:'$fieldNames', recordId: '$recordId', parentFieldName: '$parentFieldName', filter: '$filter'})
    records;


    handleSave(event) {
        var draftValuesStr = JSON.stringify(event.detail.draftValues);
        updateRecords({ sobList: this.data, updateObjStr: draftValuesStr, objectName: this.objectApiName })
        .then(result => {

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Records updated',
                    variant: 'success'
                })
            );
            // Clear all draft values
            this.draftValues = [];
            return refreshApex(this.wiredsObjectData);
        })
        .catch(error => {
            console.log('-------error-------------'+error);
            console.log(error);
        });

    }

}