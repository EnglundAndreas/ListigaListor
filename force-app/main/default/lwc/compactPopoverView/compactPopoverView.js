import { LightningElement, wire, api } from "lwc";
import { getRecordUi, getRecord } from "lightning/uiRecordApi";

export default class CompactPopoverView extends LightningElement {
  @api recordId;
  @api objectName;
  @api title;
  @wire(getRecord, {
    recordId: "$recordId",
    fields: ['Opportunity.Name'],
  })
  record;
  @wire(getRecordUi, {
    recordIds: "$recordId",
    layoutTypes: "Compact",
    modes: "View",
  })
  recordUI;
  objectName = "Opportunity";
  get recordFields() {
    if(this.recordUI.data){
        let fields = this.recordUI.data.records[this.recordId].fields;
        console.log(fields);
        return Object.keys(fields)
            .map(key => ({name:key, displayValue:fields[key].displayValue}))
            .filter(e=>!!e.displayValue);
    }

  }
  get recordName(){
      return this.record.data ? this.record.data.fields.Name.value : "";
  }
  get iconName(){
      return "standard:"+this.objectName.toLowerCase();
  }
}