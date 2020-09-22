import { LightningElement, wire, api, track } from "lwc";
import getRecordsByQuery from "@salesforce/apex/ListigaListorController.getRecordsByQuery";
import updateRecords from "@salesforce/apex/ListigaListorController.updateRecords";
import { updateRecord, deleteRecord } from "lightning/uiRecordApi";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { getRecord } from 'lightning/uiRecordApi';

export default class ListigLista extends NavigationMixin(LightningElement) {
  @api childObjectName;
  @api objectApiName;
  @api recordId;
  @api listTitle;
  @api customIconName;
  @api query;
  @api recordTypeId;
  @api rowActions;
  @api fullListView = false;
  @api showRowNumbers = false;
  @api maxColumns=99;
  @api maxRows =99;
  @api columnLabels = ' ';
  @api limitedEditForm;
  @api limitedNewForm;
  @api sortBy;
  @api sortDirection;

  data;
  totalNumberOfRows = 0;
  error;
  columns = [];
  draftValues = [];
  urlTypeFields = [];
  loading;
  loadMoreStatus;
  loadingData;
  showSpinner = true;
  objectPluralLabel;
  recordName;
  showModal = false;
  editRecordId;
  iconClass;
  iconUrl;
  icon;
  wiredResult;
  showDeleteDialog = false;
  parentFieldName;
  get dataTableStyle() {
    return this.fullListView ? "height: 500px": "";
  } 

  @wire(getRecordsByQuery, {
    query: "$query", 
    recordId: "$recordId",
    objectApiName: "$objectApiName",
    rowActions: "$rowActions",
    maxColumns: "$maxColumns",
    maxRows: "$maxRows",
    columnLabels: '$columnLabels',
    fullView: "$fullListView"
  })
  wireRecordsByQuery(result) {
    if (result.data) {
      let tempList = [];
      console.log('Hello data',result.data);

      this.wiredResult = result;
      this.data = result.data.rows;
      console.log('<< ROWS <<');
      console.log(result.data.rows);

      this.columns = result.data.columns;
      this.parentFieldName = result.data.parentFieldName;
      this.objectPluralLabel = result.data.objectPluralLabel;
      this.totalNumberOfRows = result.data.numberOfRows;
      if(!this.listTitle) {
        this.listTitle = result.data.objectPluralLabel + ' ('+this.totalNumberOfRows+')';
      }
      this.childObjectName = result.data.objectApiName;
      this.recordName = result.data.recordName;
      this.iconUrl = result.data.icon.iconURL;
      this.iconClass = result.data.icon.iconStyle;
    } else if (result.error) {
      let error = result.error;
      let message = "Unknown error";
      if (Array.isArray(error.body)) {
        message = error.body.map((e) => e.message).join(", ");
      } else if (typeof error.body.message === "string") {
        message = error.body.message;
      }
      this.error = message;
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Error loading Records",
          message,
          variant: "error",
        })
      );
    }
    this.showSpinner = false;
  }

  handleSave(event) {
    var draftValuesStr = JSON.stringify(event.detail.draftValues);
    console.log('draftValuesStr '+draftValuesStr);
    updateRecords({
      sObjList: this.data,
      updateObjStr: draftValuesStr,
      objectName: this.childObjectName,
    }).then((result) => {
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
      });
  }

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;
    switch (actionName) {
    case 'edit':
      if(this.limitedEditForm) {
        this.editRecordId = row.Id;
        this.showModal = true;
      } else {
        this.editRecordFullView(row);
      }
      break;
    case 'view':
      this.viewRecord(row);
      break;
    case 'delete':
      this.originalMessage = row;
      this.showDeleteDialog = true;
      //this.deleteRecord(row);
      break;
    default:
      this.viewRecord(row);
      break;
    }
  }

  handleDelete(event) {
    if(event.detail.status === 'confirm') {
      let row = event.detail.originalMessage;
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
          this.dispatchEvent(
              new ShowToastEvent({
                  title: 'Error deleting record',
                  message: error.body.message,
                  variant: 'error'
              })
          );
      });
    }
    this.showDeleteDialog = false;
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


  editRecordFullView(row) {
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
    if(this.limitedNewForm) { // Custom Limited View
      this.editRecordId = null;
      this.showModal = true;
    } else { // Standard Full View
      if(this.parentFieldName !== null) {
        defaultFieldValues = this.parentFieldName +"="+this.recordId;
      }
      this[NavigationMixin.Navigate]({
        type: 'standard__objectPage',
        attributes: {
          objectApiName: this.childObjectName,
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
        this.error = error;
        console.error(error);
      });
    }
  }

  updateColumnSorting(event) {
    let fieldName = event.detail.fieldName;
    let sortDirection = event.detail.sortDirection;
    this.sortBy = fieldName;
    this.sortDirection = sortDirection;
    this.sortData(fieldName, sortDirection);
  }

   sortData(fieldName, direction) {
      let parseData = JSON.parse(JSON.stringify(this.data));
      let keyValue = (a) => {
          return a[fieldName];
      };
      let isReverse = direction === 'asc' ? 1: -1;

      parseData.sort((x, y) => {
          x = keyValue(x) ? keyValue(x) : ''; // handling null values
          y = keyValue(y) ? keyValue(y) : '';

          return isReverse * ((x > y) - (y > x));
      });

      this.data = parseData;
  }

  clickViewAll() {
    console.log('view All');
    this[NavigationMixin.Navigate]({
      type: "standard__component",
      attributes: {
          componentName: "c__listFullView",
      },
      state: {
        c__recordId: this.recordId,
        c__childObjectName: this.childObjectName,
        c__objectApiName: this.objectApiName,
        c__listTitle: this.listTitle,
        c__iconName: this.iconName,
        c__query: this.query,
        c__parentFieldName: this.parentFieldName,
        c__rowActions: this.rowActions,
        c__objectPluralLabel: this.objectPluralLabel,
        c__recordName: this.recordName,
        c__columnLabels: this.columnLabels,
        c__limitedNewForm: this.limitedNewForm,
        c__limitedEditForm: this.limitedEditForm
      }
    });

  }


  updateDataValues(updateItem) {
    console.log('update Data Values ',updateItem);
    let copyData = [... this.data];
    copyData.forEach(item => {
        if (item.Id === updateItem.Id) {
            for (let field in updateItem) {
                item[field] = updateItem[field];
            }
        }
    });

    //write changes back to original data
    this.data = [...copyData];
}

  updateDraftValues(updateItem) {
      let draftValueChanged = false;
      let copyDraftValues = [...this.draftValues];
      //store changed value to do operations
      //on save. This will enable inline editing &
      //show standard cancel & save button
      copyDraftValues.forEach(item => {
          if (item.Id === updateItem.Id) {
              for (let field in updateItem) {
                  item[field] = updateItem[field];
              }
              draftValueChanged = true;
          }
      });

      if (draftValueChanged) {
          this.draftValues = [...copyDraftValues];
      } else {
          this.draftValues = [...copyDraftValues, updateItem];
      }
  }

  handleCancel(event) {
    //remove draftValues & revert data changes
    //this.data = JSON.parse(JSON.stringify(this.lastSavedData));
    this.draftValues = [];
  }

  handleModalClose(event) {
   this.showModal = false;
  }

  handleModalSuccess(event) {
    this.showModal = false;
    console.log('i guess success?');
    return refreshApex(this.wiredResult);
   }

  loadMoreData(event) {
    //Display a spinner to signal that data is being loaded
    //event.target.isLoading = true;
    //Display "Loading" when more data is being loaded
    console.log('<< loadMoreData');
    const currentData = this.data;
    const lastRecId = currentData[currentData.length - 1].Id;
    if(currentData.length < this.totalNumberOfRows && this.fullListView) {
      console.log('Oh yeah')
      this.loadingData = true;
      getRecordsByQuery({
        query: this.query, 
        recordId: this.recordId, 
        objectApiName: this.objectApiName,
        rowActions: this.rowActions,
        columnLabels: this.columnLabels,
        fullView: this.fullListView,
        lastRowRecordId: lastRecId})
        .then(result => {
          const loadedData = result.rows;
          //Appends new data to the end of the table
          console.log(this.data);
          console.log(this.data.length);
          console.log(this.totalNumberOfRows);
          const newData = currentData + loadedData;
          this.data = newData;
      })
      .catch(error => {
          console.log('-------error-------------',error);
          console.log(error);
      });
    }
    this.loadingData = false;
    console.log('lastRecId ', lastRecId);
   
  }

}