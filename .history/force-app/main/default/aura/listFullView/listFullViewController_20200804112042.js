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
    }
})
