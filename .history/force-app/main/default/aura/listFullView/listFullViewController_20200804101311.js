({
    doInit : function(component, event, helper) {
        var myPageRef = component.get("v.pageReference");
        var state = myPageRef.state;
        console.log('state ');
        console.log(state);
        component.set("v.recordId", state.c__recordId);
        component.set("v.listTitle", state.c__listTitle);
    }
})
