({
    doInit : function(component, event, helper) {
        var myPageRef = component.get("v.pageReference");
        var state = myPageRef.state;
        console.log('state '+JSON.stringify(state));
        component.set("v.recordId", state.recordId);
        component.set("v.listTitle", state.c__listTitle);
    }
})
