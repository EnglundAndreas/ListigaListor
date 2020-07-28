public with sharing class ListigaListorController {

    @AuraEnabled(cacheable=true)
    public static List<SObject> getRecordsByQuery(String query, String recordId, String objectApiName){
        Pattern p = Pattern.compile ('\\$record\\.([\\w]+)');
        Matcher pm = p.matcher(query);
        List<String> selectFields = new List<String>();
        while(pm.find()) {
            System.debug(pm.group(1));
            selectFields.add(pm.group(1));
        }
        if(!selectFields.isEmpty()){
            String recordQuery = 'SELECT '+String.join(selectFields, ', ')+' FROM '+objectApiName+' WHERE Id = \''+recordId +'\' LIMIT 1';
            System.debug('recordQuery '+recordQuery);
            SObject record = Database.query(recordQuery);
            System.debug('record '+record);
            Map<String, Object> recordFieldMap = record.getPopulatedFieldsAsMap();
            for(String fieldName : recordFieldMap.keySet()){
                Object fieldValue = recordFieldMap.get(fieldName);
                Boolean fieldNeedsQuotes = ListigaListorController.typeNeedsQuotes.get(getType(fieldValue));
                if(fieldNeedsQuotes){
                    query = query.replaceAll('\\$record\\.'+fieldName, '\''+String.valueOf(fieldValue)+'\'');
                }else{
                    query = query.replaceAll('\\$record\\.'+fieldName, String.valueOf(fieldValue));
                }
            }
        }
        System.debug('query '+query);

//        query = query.replace('$recordId', '\''+recordId+'\'');
        System.debug('query after replace '+query);
        return Database.query( query );
    }

    @AuraEnabled
    public static String getFieldLabel(String apiName, String objectName) {
        String fieldLabel = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().get(apiName).getDescribe().getLabel();
        System.debug(fieldLabel);
        return fieldLabel;
    }

    @AuraEnabled
    public static void updateRecords(List<SObject> sObjList, String updateObjStr, String objectName) {
        System.debug('<< sObjList '+sObjList);
        
        
        Schema.SObjectType sobjType = Schema.getGlobalDescribe().get(ObjectName);

        Map<String, Schema.sObjectField> sObjectFields = sobjType.getDescribe().fields.getMap();
        List<sObject> updateList = new List<sObject>();
        List<Object> obList = (List<object>) json.deserializeUntyped(updateObjStr);
        for(Object ob : obList) {
            Map<String, object> obmap = (Map<String, object>)ob;
            String rowKey = (String)obmap.get('id');
            Integer rowKeyInt = Integer.ValueOf(rowKey.removeStart('row-'));

            sobject sObj = sObjList[rowKeyInt];
            for(String fieldName : obmap.keySet()) {
                if(fieldName != 'id') {
                    Object value = obmap.get(fieldName);
                    Schema.DisplayType valueType = sObjectFields.get(fieldName).getDescribe().getType();
                    if (value instanceof String && valueType != Schema.DisplayType.String)
                    {
                        String svalue = (String)value;
                        if (valueType == Schema.DisplayType.Date)
                            sObj.put(fieldName, Date.valueOf(svalue));
                        else if(valueType == Schema.DisplayType.DateTime) {
                            try{
                                System.debug( (DateTime)value);
                            }catch(exception ex) {
                                System.debug(ex.getmessage());
                            }
                            String d1 = svalue;
                            List<String> d2 = d1.split('-');
                            List<integer> timeComponent = new List<integer>();
                            timeComponent.add(Integer.valueOf(d2[0]));
                            timeComponent.add(Integer.valueOf(d2[1]));
                            timeComponent.add(Integer.valueOf(d2[2].left(2)));

                            String t = d2[2].substringBetween('T','.');

                            List<String> time1 = t.split(':');
                            timeComponent.add(Integer.valueOf(time1[0]));
                            timeComponent.add(Integer.valueOf(time1[1]));
                            timeComponent.add(Integer.valueOf(time1[2]));

                            Datetime dt = Datetime.newInstance(timeComponent[0],timeComponent[1],timeComponent[2],timeComponent[3],timeComponent[4],timeComponent[5]);
                            sObj.put(fieldName, dt);
                        }
                        //
                        else if (valueType == Schema.DisplayType.Percent || valueType == Schema.DisplayType.Currency)
                            sObj.put(fieldName, svalue == '' ? null : Decimal.valueOf(svalue));
                        else if (valueType == Schema.DisplayType.Double)
                            sObj.put(fieldName, svalue == '' ? null : Double.valueOf(svalue));
                        else if (valueType == Schema.DisplayType.Integer)
                            sObj.put(fieldName, Integer.valueOf(svalue));
                        else if (valueType == Schema.DisplayType.Base64)
                            sObj.put(fieldName, Blob.valueOf(svalue));
                        else
                            sObj.put(fieldName, svalue);
                    }
                    else
                        sObj.put(fieldName, value);
                }
            }
            updateList.add(sObj);
        }

        update updateList;
    }
    public static string getType(Object o) {
        if(o==null) return '';              // we can't say much about null with our current techniques
        if(o instanceof SObject)            return ((SObject)o).getSObjectType().getDescribe().getName()+'';
        if(o instanceof Boolean)            return 'Boolean';
        if(o instanceof Id)                 return 'Id';
        if(o instanceof String)             return 'String';
        if(o instanceof Blob)               return 'Blob';
        if(o instanceof Date)               return 'Date';
        if(o instanceof Datetime)           return 'Datetime';
        if(o instanceof Time)               return 'Time';
        if(o instanceof String)             return 'String';
        if(o instanceof Integer)            return 'Integer';
        if(o instanceof Long)               return 'Long';
        if(o instanceof Decimal)            return 'Decimal';  // we can't distinguish between decimal and double
        if(o instanceof Double)             return 'Double';   // we can't distinguish between decimal and double
        if(o instanceof List<object>)       return 'List';
        return 'Object';                    // actually we can't detect maps and sets and maps
    }
    private static Map<String,Boolean> typeNeedsQuotes = new Map<String,Boolean>{
        'Boolean' => true,
        'Id' => true,
        'String' => true,
        'Blob' => false,
        'Date' => true,
        'Datetime' => true,
        'String' => true,
        'Integer' => false,
        'Long' => false,
        'Decimal' => false,
        'Double' => false,
        'List' => false
    };

}