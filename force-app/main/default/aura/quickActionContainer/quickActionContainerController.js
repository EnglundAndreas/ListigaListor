({
    doInit : function(component, event, helper) {
        console.log('<< inside Quick Action');
        var myPageRef = component.get("v.pageReference");
        var state = myPageRef.state;
        console.log('state '+JSON.stringify(state));
        component.set("v.actionName", state.c__actionName);
        component.set("v.recordId", state.c__recordId);
        var actionAPI = cmp.find("quickActionAPI");
        var actionName = component.get("v.actionName");
        var recordId = component.get("v.recordId");
        console.log('action Name: ',actionName);
        var args = {
            actionName: actionName,
            parentFields: {
                AccountId : {value: recordId}
            }
        };
        actionAPI.setActionFieldValues(args).then(function(result){
            console.log('<< quick action result');
            console.log(result);
            //Action selected; show data and set field values
        }).catch(function(e){
            if(e.errors){
                console.log(e.errors);
                //If the specified action isn't found on the page, show an error message in the my component
            }
        });
    }
})