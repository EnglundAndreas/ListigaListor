({
    doInit : function(component, event, helper) {
        var myPageRef = component.get("v.pageReference");
        var state = myPageRef.state;
        console.log('state '+JSON.stringify(state));
        component.set("v.recordId", state.c__recordId);
        component.set("v.childObjectName", state.c__childObjectName);
        component.set("v.objectApiName", state.c__objectApiName);
        component.set("v.listTitle", state.c__listTitle);
        component.set("v.iconName", state.c__iconName);
        component.set("v.query", state.c__query);
        component.set("v.parentFieldName", state.c__parentFieldName);
        component.set("v.enableRowActions", state.c__enableRowActions);
        component.set("v.objectPluralLabel", state.c__objectPluralLabel);
        component.set("v.recordName", state.c__recordName);
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
