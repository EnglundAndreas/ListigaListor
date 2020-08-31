import { LightningElement, wire, api, track } from "lwc";
import getRecordsByQuery from "@salesforce/apex/ListigaListorController.getRecordsByQuery";
import updateRecords from "@salesforce/apex/ListigaListorController.updateRecords";
import { updateRecord, deleteRecord } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getObjectInfo } from "lightning/uiObjectInfoApi";
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';

export default class ListigLista extends NavigationMixin(LightningElement) {
  @api childObjectName;
  @api objectApiName;
  @api recordId;
  @api listTitle;
  @api iconName;
  @api query;
  @api parentFieldName;
  @api recordTypeId;
  @api enableRowActions;
  @api fullListView;
  @api showRowNumbers;
  @api maxColumns;

  @track rows;
  @track totalNumberOfRows = 0;
  @track error;
  @track columns = [];
  @track draftValues = [];
  @track urlTypeFields = [];
  @track loading;
  @track showViewAll;
  @track loadMoreStatus;
  @track tableLoading;
  @track objectPluralLabel;
  @track recordName;
  wiredResult;

  @wire(getObjectInfo, { objectApiName: "$childObjectName" })
  objectData({ data, error }) {
    // if (data) {
    //   const regex = /(?<=SELECT).+?(?=FROM)/;
    //   const found = this.query.match(regex)[0].trim();
    //   const foundList = found.split(/\s*,\s*/);
    //   console.log("objectapiname: " + this.objectName);
    //   console.log('<< Data fields '+JSON.stringify(data.fields));
    //   this.columns = foundList.map((fieldName) => {
    //     if(fieldName.includes(".")) {
    //       console.log('dot not ', fieldName);
    //       let relatedObjname = fieldName.substring(0, fieldName.indexOf("."));
    //       let relatedFieldName = fieldName.substring(fieldName.indexOf(".")+1);
    //       getRelatedObjectFieldInfo({
    //         objectName: relatedObjname, 
    //         fieldName: relatedFieldName
    //       }).then((record) => {
    //         console.log('record ',record);
    //         return {
    //           fieldName: "Account",
    //           typeAttributes: {
    //             label: { fieldName: "Name" },
    //             target: "_blank",
    //           },
    //           label: record.label,getRelated
    //           type: record.dataType.toLowerCase(),
    //           editable: record.updateable,
    //           sortable: record.sortable,
    //         }
    //       });          
    //     } else if (data.fields[fieldName]) {
    //       console.log("<< hell o", fieldName);
    //       let type = data.fields[fieldName].dataType.toLowerCase();
    //       // if (type === "reference") {
    //       //   this.urlTypeFields.push(fieldName);
    //       //   console.log('url type field ', data.fields[fieldName]);
    //       //   return {
    //       //     //fieldName: "recordLink",
    //       //     fieldName,
    //       //     label: data.fields[fieldName].relationshipName,
    //       //     type: "url",
    //       //     editable: false,
    //       //     sortable: true,
    //       //     typeAttributes: {
    //       //       label: { fieldName: "Name" },
    //       //       target: "_blank",
    //       //     }
    //       //   }
    //       // } else {
    //         return {
    //           fieldName,
    //           label: data.fields[fieldName].label, 
    //           type: data.fields[fieldName].dataType.toLowerCase(),
    //           editable: data.fields[fieldName].updateable,
    //           sortable: data.fields[fieldName].sortable,
    //         }
    //       //}
    //     }
    //   });
    // }
    // if (error) {
    //   console.log("ERROR: " + JSON.stringify(error));
    // }
  }

  @wire(getRecordsByQuery, {
    query: "$query",
    recordId: "$recordId",
    objectApiName: "$objectApiName",
    enableRowActions: "$enableRowActions",
    maxColumns: "$maxColumns"
  })
  wireRecordsByQuery(result) {
    if (result.data) {
      let tempList = [];
      console.log('Hello ',result);
      // result.rows.forEach((row) => {
      //   let tempRecord = Object.assign({}, row); //cloning object  
      //   let fields = Object.getOwnPropertyNames(row);  
      //   fields.forEach((field) => {
      //     if(Object.getOwnPropertyNames(field).length > 0) {
      //       console.log('prop names  ',Object.getOwnPropertyNames(field) );
      //       console.log('lookup field ',field );
      //       console.log('row field ',row[field] );
      //       console.log('tempRec ',JSON.stringify(tempRecord) );
      //     }
      //   });
      //   tempRecord.recordLink = "/" + tempRecord.Id;
        
      //   tempList.push(tempRecord);  
      // });  
        
      console.log('wireRecordsByQuery rows '+JSON.stringify(result.data.rows));
      this.wiredResult = result;
      this.rows = result.data.rows;
      let columns = result.data.columns;
 

      columns.push({
        label: 'Parent', fieldName: 'AccountId', type: 'lookup', typeAttributes: {
          placeholder: 'Select Parent Account',
          uniqueId: { fieldName: 'Id' }, //pass Id of current record to lookup for context
          object: "Account",
          icon: "standard:account",
          label: "Account",
          displayFields: "Name, AccountNumber",
          displayFormat: "Name (AccountNumber)",
          filters: ""
        }
      });
      this.columns = columns;
      this.totalNumberOfRows = this.rows.length;
      this.objectPluralLabel = result.data.objectPluralLabel;
      this.recordName = result.data.recordName;
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
      objectName: this.childObjectName,
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

  deleteRecord(row) {
      deleteRecord(row.Id).then(() => {
        let message = 'Record deleted';
        if(row.Name){
          message.replace('Record', row.Name);
        }
          this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: message,
                variant: 'success'
            })
        );
        return refreshApex(this.wiredResult);
    }).catch(error => {
      console.log('error ',error);
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error deleting record',
                message: error.body.message,
                variant: 'error'
            })
        );
    });
  }

  findRowIndexById(Id) {
      let ret = -1;
      this.data.some((row, index) => {
          if (row.Id === Id) {
              ret = index;
              return true;
          }
          return false;
      });
      return ret;
  }


  editRecord(row) {
    console.log('Edit ',JSON.stringify(row));
    console.log('Id ',row.Id);
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
    this.loading = true;
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
          navigationLocation: 'RELATED_LIST',
          recordTypeId: this.recordTypeId
      }
    }).then(result => {
      console.log(result);
      return refreshApex(this.wiredResult);

    }).catch(error => {
      console.log(error);
    }); 
  }

  clickViewAll() {
    this[NavigationMixin.Navigate]({
      type: "standard__component",
      attributes: {
          componentName: "c__listFullView",
          recordId: this.recordId,
          listTitle: this.listTitle,
      },
      state: {
        c__recordId: this.recordId,
        c__childObjectName: this.childObjectName,
        c__objectApiName: this.objectApiName,
        c__listTitle: this.listTitle,
        c__iconName: this.iconName,
        c__query: this.query,
        c__parentFieldName: this.parentFieldName,
        c__enableRowActions: this.enableRowActions,
        c__objectPluralLabel: this.objectPluralLabel,
        c__recordName: this.recordName,
      }
    });
      
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