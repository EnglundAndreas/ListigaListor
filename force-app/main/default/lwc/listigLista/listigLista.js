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
  @api parentFieldName;
  @api recordTypeId;
  @api enableRowActions;
  @api fullListView;
  @api showRowNumbers;
  @api maxColumns=99;
  @api maxRows =99;
  @api columnLabels = ' ';
  @api columnEditView = ' ';

  data;
  totalNumberOfRows = 0;
  error;
  columns = [];
  draftValues = [];
  urlTypeFields = [];
  loading;
  showViewAll;
  loadMoreStatus;
  tableLoading;
  objectPluralLabel;
  recordName;
  showModal = false;
  editRecordId;
  editRecord;
  iconClass;
  iconUrl;
  icon;
  wiredResult;

  connectedCallback() {
    console.log('child comp instantiated');
  }

  @wire(getRecordsByQuery, {
    query: "$query",
    recordId: "$recordId",
    objectApiName: "$objectApiName",
    enableRowActions: "$enableRowActions",
    maxColumns: "$maxColumns",
    maxRows: "$maxRows",
    columnLabels: '$columnLabels'
  })
  wireRecordsByQuery(result) {
    console.log('records by query ', JSON.stringify(result));
    console.log('inputs ', this.query, this.recordId, this.objectApiName, this.enableRowActions, this.maxColumns);
    if (result.data) {
      let tempList = [];
      console.log('Hello data',result.data);

      this.wiredResult = result;
      this.data = result.data.rows;
      console.log('<< ROWS <<');
      console.log(result.data.rows);
      let columns = result.data.columns;
      let jsonColumns = JSON.stringify(columns).replace('objectX', 'object');
      let cols = JSON.parse(jsonColumns);

      this.columns = cols;
      this.totalNumberOfRows = this.data.length;
      this.objectPluralLabel = result.data.parentObjectPluralLabel;
      if(!this.listTitle) {
        this.listTitle = result.data.objectPluralLabel;
      }
      this.childObjectName = result.data.objectApiName;
      this.recordName = result.data.recordName;
      this.iconUrl = result.data.icon.iconURL;
      this.iconClass = result.data.icon.iconStyle;
      console.log('icon '+JSON.stringify(result.data.icon));
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
    console.log('<< row '+JSON.stringify(row));
    console.log(event);
    switch (actionName) {
    case 'edit':
        console.log('edit clicked');
        this.editRecordId = row.Id;
        this.editRecord = row;
        this.showModal = true;
        //this.editRecordFullView(row);
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
        c__enableRowActions: this.enableRowActions,
        c__objectPluralLabel: this.objectPluralLabel,
        c__recordName: this.recordName,
      }
    });

  }


  updateDataValues(updateItem) {
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

    //listener handler to get the context and data
    //updates datatable
  // picklistChanged(event) {
  //     event.stopPropagation();
  //     let dataRecieved = event.detail.data;
  //     let updatedItem = { Id: dataRecieved.context, Rating: dataRecieved.value };
  //     this.updateDraftValues(updatedItem);
  //     this.updateDataValues(updatedItem);
  // }

  // handleSelection(event) {
  //   event.stopPropagation();
  //   let dataRecieved = event.detail.data;
  //   let updatedItem = { Id: dataRecieved.key, ParentId: dataRecieved.selectedId };
  //   this.updateDraftValues(updatedItem);
  //   this.updateDataValues(updatedItem);
  // }
  // handleCellChange(event) {
  //   this.updateDraftValues(event.detail.draftValues[0]);
  // }

  handleCancel(event) {
    //remove draftValues & revert data changes
    //this.data = JSON.parse(JSON.stringify(this.lastSavedData));
    this.draftValues = [];
  }

  handleClose(event) {
   console.log('close Modal!');
   this.showModal = false;
  }
  handleSubmit(event) {
    console.log('form submitted!');
    this.showModal = false;
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