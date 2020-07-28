import { LightningElement, wire, api, track } from "lwc";
import getRecordsByQuery from "@salesforce/apex/ListigaListorController.getRecordsByQuery";
import updateRecords from "@salesforce/apex/ListigaListorController.updateRecords";
import getFieldLabel from "@salesforce/apex/ListigaListorController.getFieldLabel";
import { updateRecord } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';

export default class ListigLista extends NavigationMixin(LightningElement) {
  @api objectName;
  @api objectApiName;
  @api recordId;
  @api listTitle;
  @api iconName;
  @api query;
  @api parentFieldName;
  @api recordTypeId;
  @api maxListHeight;
  @track records;
  @track numberOfRecords;
  @track error;
  @track columns = [];
  @track draftValues = [];
  @track urlTypeFields = [];
  @track loading;
  @track showViewAll;
  @track fullListView;
  wiredResult;
  
  connectedCallback(){
    var dataTable = document.querySelector('#listDataTable');
    dataTable.style.height = this.maxListHeight;    
  }

  @wire(getObjectInfo, { objectApiName: "$objectName" })
  objectData({ data, error }) {
    if (data) {
      const regex = /(?<=SELECT).+?(?=FROM)/;
      const found = this.query.match(regex)[0].trim();
      const foundList = found.split(/\s*,\s*/);
      console.log("objectapiname: " + this.objectName);
      console.log("foundList", foundList);
      console.log(JSON.stringify(data.fields));
      this.columns = foundList.map((fieldName) => {
        if(fieldName.includes(".")) {
          let relatedObjname = fieldName.substring(0, fieldName.indexOf("."));
          console.log('relatedObjname ',relatedObjname);
        }
        console.log('fieldname ',fieldName);
        if(data.fields[fieldName] == null)  {
          console.log('fail');
          return {
            fieldName,
            label: 'Test',
            type: "string",
            editable: false
          }
        } 

        let type = data.fields[fieldName].dataType.toLowerCase();
        console.log('this is the type ',type);
        if (type === "reference") {
          this.urlTypeFields.push(fieldName);
          return {
            fieldName,
            label: data.fields[fieldName].relationshipName,
            type: "url",
            editable: false,
            typeAttributes: {
              label: { fieldName: "Name" },
              target: "www.google.com",
            },
          };
        } else {
          return {
            fieldName,
            label: data.fields[fieldName].label,
            type: data.fields[fieldName].dataType.toLowerCase(),
            editable: data.fields[fieldName].updateable,
          };
        }
      });

      console.log(this.columns);
    }
    if (error) {
      console.log("ERROR: " + JSON.stringify(error));
    }
  }

  @wire(getRecordsByQuery, {
    query: "$query",
    recordId: "$recordId",
    objectApiName: "$objectApiName",
  })
  wireRecordsByQuery(result) {
    if (result.data) {
      console.log(JSON.stringify(result.data));
      this.wiredResult = result;
      this.records = result.data;
      this.listTitle+=' ('+result.data.length+')';
    } else if (result.error) {
      let error = result.error;
      console.error(error);
      let message = "Unknown error";
      if (Array.isArray(error.body)) {
        message = error.body.map((e) => e.message).join(", ");
      } else if (typeof error.body.message === "string") {
        message = error.body.message;
      }
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error loading Records",
          message,
          variant: "error",
        })
      );
    }
  }

  handleSave(event) {
    var draftValuesStr = JSON.stringify(event.detail.draftValues);
    console.log('draftValuesStr '+draftValuesStr);
    console.log('records '+this.records);
    updateRecords({
      sObjList: this.records,
      updateObjStr: draftValuesStr,
      objectName: this.objectName,
    })
      .then((result) => {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Success",
            message: "Records updated",
            variant: "success",
          })
        );
        // Clear all draft values
        this.draftValues = [];
        return refreshApex(this.wiredResult);
      })
      .catch((error) => {
        console.log("-------error-------------" + JSON.stringify(error));
        console.log(error);
      });
  }

  @wire(CurrentPageReference)
  wiredPageRef() {
      this.loading = CurrentPageReference;
  }

  createNew() {
    let defaultFieldValues = '';
    if(this.parentFieldName !== null) {
      defaultFieldValues = this.parentFieldName +"="+this.recordId;
    }
  
    this[NavigationMixin.Navigate]({
      type: 'standard__objectPage',
      attributes: {
        objectApiName: 'Contact',
        actionName: 'new'                
      },
      state : { 
          nooverride: '1',
          defaultFieldValues: defaultFieldValues,
          recordTypeId: this.recordTypeId
      }
    });
    //return refreshApex(this.wiredResult);
    this.loading = true;

  }
}

const getSelectFields = (queryInp) => {
  let pattern = /\$record\.([\w]+)/g;
  console.log("query " + this.query);
  let fields = [...queryInp.matchAll(pattern)].map((e) => e[1]).join(", ");
  return fields;
};