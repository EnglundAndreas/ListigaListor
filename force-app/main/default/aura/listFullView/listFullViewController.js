({
    doInit : function(component, event, helper) {
        var myPageRef = component.get("v.pageReference");
        var state = myPageRef.state;
        component.set("v.recordId", state.c__recordId);
        component.set("v.childObjectName", state.c__childObjectName);
        component.set("v.objectApiName", state.c__objectApiName);
        component.set("v.listTitle", state.c__listTitle);
        component.set("v.customIconName", state.c__customIconName);
        component.set("v.query", state.c__query);
        component.set("v.parentFieldName", state.c__parentFieldName);
        component.set("v.rowActions", state.c__rowActions);
        component.set("v.objectPluralLabel", state.c__objectPluralLabel);
        component.set("v.recordName", state.c__recordName);
        component.set("v.columnLabels", state.c__columnLabels);
        component.set("v.limitedNewForm", state.c__limitedNewForm);
        component.set("v.limitedEditForm", state.c__limitedEditForm);
        component.set("v.showCheckboxColumn", state.c__showCheckboxColumn);
        component.set("v.rowsPerPage", state.c__rowsPerPage);
    },
    navigateToObjectHome : function(component, event, helper) {
        var homeEvent = $A.get("e.force:navigateToObjectHome");
        homeEvent.setParams({
            "scope": component.get("v.childObjectName")
        });
        homeEvent.fire();
    },
    navigateToRecord : function(component, event, helper) {
        var navEvt = $A.get("e.force:navigateToSObject");
        navEvt.setParams({
          "recordId": component.get("v.recordId"),
          "slideDevName": "related"
        });
        navEvt.fire();
    },
})