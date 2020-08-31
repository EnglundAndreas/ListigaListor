import { LightningElement, wire, api, track } from "lwc";
import getRecordsByQuery from "@salesforce/apex/ListigaListorController.getRecordsByQuery";
import updateRecords from "@salesforce/apex/ListigaListorController.updateRecords";
import getRelatedObjectFieldInfo from "@salesforce/apex/ListigaListorController.getRelatedObjectFieldInfo";
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
  @api maxListHeight = 250;
  @api enableRowActions;
  @track data;
  @track totalNumberOfRows;
  @track error;
  @track columns = [];
  @track draftValues = [];
  @track urlTypeFields = [];
  @track loading;
  @track showViewAll;
  @track fullListView;
  @track loadMoreStatus;
  @track tableLoading;
  wiredResult;
  
  connectedCallback(){
    console.log('totalNumberOfRows ', this.totalNumberOfRows);
  }

  @wire(getObjectInfo, { objectApiName: "$objectName" })
  objectData({ data, error }) {
    if (data) {
      const regex = /(?<=SELECT).+?(?=FROM)/;
      const found = this.query.match(regex)[0].trim();
      const foundList = found.split(/\s*,\s*/);
      console.log("objectapiname: " + this.objectName);
      console.log('<< Data fields '+JSON.stringify(data.fields));
      this.columns = foundList.map((fieldName) => {
        if(fieldName.includes(".")) {
          console.log('dot not ', fieldName);
          let relatedObjname = fieldName.substring(0, fieldName.indexOf("."));
          let relatedFieldName = fieldName.substring(fieldName.indexOf(".")+1);
          getRelatedObjectFieldInfo({
            objectName: relatedObjname, 
            fieldName: relatedFieldName
          }).then((record) => {
            console.log('record ',record);
            return {
              fieldName: relatedObjname,
              typeAttributes: {
                label: { fieldName: relatedFieldName },
                target: "_blank",
              },
              label: record.label,
              type: record.dataType.toLowerCase(),
              editable: record.updateable,
              sortable: record.sortable,
            }
          });          
        } else if (data.fields[fieldName]) {
          console.log("<< hell o", fieldName);
          let type = data.fields[fieldName].dataType.toLowerCase();
          // if (type === "reference") {
          //   this.urlTypeFields.push(fieldName);
          //   console.log('url type field ', data.fields[fieldName]);
          //   return {
          //     //fieldName: "recordLink",
          //     fieldName,
          //     label: data.fields[fieldName].relationshipName,
          //     type: "url",
          //     editable: false,
          //     sortable: true,
          //     typeAttributes: {
          //       label: { fieldName: "Name" },
          //       target: "_blank",
          //     }
          //   }
          // } else {
            return {
              fieldName,
              label: data.fields[fieldName].label, 
              type: data.fields[fieldName].dataType.toLowerCase(),
              editable: data.fields[fieldName].updateable,
              sortable: data.fields[fieldName].sortable,
            }
          //}
        }
      });
    }
    if (error) {
      console.log("ERROR: " + JSON.stringify(error));
    }
  }

  @wire(getRecordsByQuery, {
    query: "$query",
    recordId: "$recordId",
    objectApiName: "$objectApiName"
  })
  wireRecordsByQuery(result) {
    if (result.data) {
      let tempList = [];
     
      result.data.forEach((row) => {
        let tempRecord = Object.assign({}, row); //cloning object  
        let fields = Object.getOwnPropertyNames(row);  
        fields.forEach((field) => {
          if(Object.getOwnPropertyNames(field).length > 0) {
            console.log('prop names  ',Object.getOwnPropertyNames(field) );
            console.log('lookup field ',field );
            console.log('row field ',row[field] );
            console.log('tempRec ',JSON.stringify(tempRecord) );
          }
        });
        tempRecord.recordLink = "/" + tempRecord.Id;
        
        tempList.push(tempRecord);  
      });  
        
      console.log('wireRecordsByQuery '+JSON.stringify(result.data));

      this.wiredResult = result;
      this.data = tempList;
      this.totalNumberOfRows = result.data.length;
      this.listTitle+=' ('+result.data.length+')';
    } else if (result.error) {
      let error = result.error;
      let message = "Unknown error";
      console.error(message, error);
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
    updateRecords({
      sObjList: this.data,
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

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;
    switch (actionName) {
    case 'edit':
        this.editRecord(row);
        break;
    case 'view':
        this.viewRecord(row);
        break;
    case 'delete':
        this.deleteRecord(row);
        break;
    default:
        this.viewRecord(row);
        break;
    }
  }

  //currently we are doing client side delete, we can call apex tp delete server side
  deleteRecord(row) {
      const { id } = row;
      const index = this.findRowIndexById(id);
      if (index !== -1) {
          this.data = this.data
              .slice(0, index)
              .concat(this.data.slice(index + 1));
      }
  }

  findRowIndexById(id) {
      let ret = -1;
      this.data.some((row, index) => {
          if (row.id === id) {
              ret = index;
              return true;
          }
          return false;
      });
      return ret;
  }


  editRecord(row) {
      this[NavigationMixin.Navigate]({
          type: 'standard__recordPage',
          attributes: {
              recordId: row.Id,
              actionName: 'edit',
          },
      });
  }

  viewRecord(row) {
      this[NavigationMixin.Navigate]({
          type: 'standard__recordPage',
          attributes: {
              recordId: row.Id,
              actionName: 'view',
          },
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

  loadMoreData(event) {
    //Display a spinner to signal that data is being loaded
    //event.target.isLoading = true;
    //Display "Loading" when more data is being loaded
    console.log('<< loadMoreData');
    this.loadMoreStatus = 'Loading';
    const currentData = this.data;
    const lastRecId = currentData[currentData.length - 1].Id;

    getRecordsByQuery({ query: this.query, recordId: this.recordId, objectApiName: this.objectApiName})
      .then(result => {
        //Appends new data to the end of the table
        const newData = currentData.concat(result);
        this.data = newData; 
        if (this.data.length >= this.totalNumberOfRows) {
            this.loadMoreStatus = 'No more data to load';
        } else {
            this.loadMoreStatus = '';
        }
        this.tableLoading = false;
      //  event.target.isLoading = false;
    })
    .catch(error => {
        console.log('-------error-------------'+error);
        console.log(error);
    });
  }

}

const getSelectFields = (queryInp) => {
  let pattern = /\$record\.([\w]+)/g;
  console.log("query " + this.query);
  let fields = [...queryInp.matchAll(pattern)].map((e) => e[1]).join(", ");
  return fields;
};