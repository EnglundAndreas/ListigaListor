public with sharing class ListigaListorController {
    public static Integer loadLimit = 50;
    public static String defaultSortOrder = ' ORDER BY CreatedDate DESC';
    @AuraEnabled
    public String relatedObjSeparator = '_relobj_';

    @AuraEnabled(cacheable=true)
    public static DataTable getRecordsByQuery(String query, String recordId, String objectApiName, Boolean enableRowActions, Integer maxColumns){
        String lastRowRecordId;
        List<String> rowActions = new List<String> {'View', 'Edit', 'Delete'};
        System.debug('this is query '+query);
        SObject record = getMainRecord(query, recordId, objectApiName);
        query = setQuerySelectRecordFields(record, query);

        if(String.isNotBlank(lastRowRecordId)) {
            query = setQueryLastRowRecordId(query, lastRowRecordId);
        }
        if(!query.contains('ORDER BY')) {
            query += defaultSortOrder;
        }
        query += ' NULLS LAST LIMIT '+loadLimit;
        System.debug('this is the query '+query);
        List<SObject> records = Database.query( query );
        System.debug('result from query '+records);
        List<String> fieldNames = getFieldsFromQuery(query);
        String mainObjectName = getObjectName(query);
        
        DataTable dataTable = new DataTable();
        dataTable.objectPluralLabel = getSObjectInfo(objectApiName).getLabelPlural();
        dataTable.recordName = String.valueOf(record.get('Name'));
        dataTable.rows = getRows(records, fieldNames);
        dataTable.columns = getColumns(fieldNames, rowActions, mainObjectName, enableRowActions, maxColumns);
        return dataTable;
    }

    static DescribeFieldResult getFieldInfo(Map<String, SObjectField> objectFieldMap, String fieldName) {
       return objectFieldMap.get(fieldName).getDescribe();
    }

    static DescribeSObjectResult getSObjectInfo(String objectName) {
        return Schema.getGlobalDescribe().get(objectName).getDescribe();
    }

    static String getObjectName(String query) {
        if(query.contains('WHERE')) {
            return query.substringBetween('FROM ', ' WHERE').trim();
        }
        return query.substringBetween('FROM ', ' ').trim();
    } 
   
    static List<Column> getColumns(List<String> fieldNames, List<String> rowActions, String mainObjectName, Boolean enableRowActions, Integer maxColumns) {
        List<Column> columns = new List<Column>();
        Map<String, SObjectField> fieldInfoMap = getSObjectInfo(mainObjectName).fields.getMap();
        Integer counter = 1;
        for(String field : fieldNames) {
            if(maxColumns != null && counter == maxColumns) break;

            Column col = new Column();
            DescribeFieldResult fieldInfo;
            Boolean relationField = field.contains('.');
            if(relationField) {
                String relObjname = field.substring(0, field.indexOf('.'));
                String relFieldName = field.substring(field.indexOf('.')+1);
                Map<String, SObjectField> relObjFieldMap = getSObjectInfo(relObjname).fields.getMap();
                fieldInfo = getFieldInfo(relObjFieldMap, relFieldName);
            } else {
                fieldInfo = getFieldInfo(fieldInfoMap, field);
                
            }
            String fieldType = fieldInfo.getType().name().toLowerCase();
            if(fieldType == 'reference') {
                System.debug('Reference fieldINfo '+ fieldInfo);
                col.label = fieldInfo.getLabel();
                col.fieldName = field;
                col.type = 'lookup';
                TypeAttributes typeAttr = new TypeAttributes();
                typeAttr.placeholder = 'Search '+fieldInfo.getReferenceTo()[0].getDescribe().getLabel();
                Column uniqueId = new Column();
                uniqueId.fieldName = field;
                typeAttr.uniqueId = uniqueId;
                typeAttr.objectX = 'Account';
                typeAttr.icon = 'standard:account';
                typeAttr.label = fieldInfo.getLabel();
                typeAttr.displayFields = 'Name';
                typeAttr.displayFormat = 'Name'; 
                typeAttr.filters = '';
                col.typeAttributes = typeAttr;
            } else {
                col.label = fieldInfo.getLabel();
                col.fieldName = field;
                col.type = fieldType;
                col.editable = !relationField && fieldInfo.isUpdateable();
                col.sortable = fieldInfo.isSortable();
            }
            columns.add(col);
            counter ++;
        }
        if(enableRowActions) {
            Column actionsCol = new Column();
            actionsCol.typeAttributes = new TypeAttributes(rowActions);
            actionsCol.type = 'action';
            columns.add(actionsCol);
        }
       
        return columns;
    }

    static List<Map<String, Object>> getRows(List<SObject> records, List<String> fieldNames) {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        for(SObject record : records ) {
            Map<String, Object> row = new Map<String, Object>();
            for(String fieldName : fieldNames) {
                Boolean relationField = fieldName.contains('.'); 
                Boolean editable = !relationField;
                String relObjname;
                String relFieldName;
                Object fieldValue;
                if(relationField) {
                    relObjname = fieldName.substring(0, fieldName.indexOf('.'));
                    relFieldName = fieldName.substring(fieldName.indexOf('.')+1);
                    fieldValue = record.getSObject(relObjname).get(relFieldName);
                } else {
                    fieldValue = record.get(fieldName);
                }
                row.put(fieldName, fieldValue);
            }
                row.put('Id', record.Id);
            rows.add(row);
        }
        return rows;
    }

    static List<String> getFieldsFromQuery(String query) {
        List<String> fields = new List<String>();
        for(String field : query.substringBetween('SELECT', 'FROM').split(',')) {
            fields.add(field.trim());
        }
        return fields;
    }

    static String setQueryLastRowRecordId(String query, String lastRowRecordId) {

        if(!query.contains('WHERE')) {
            query += ' WHERE Id > ';
        } else {
            query += ' AND Id > ';
        }
        query += lastRowRecordId;
        return query;
    }

    static String setQuerySelectRecordFields(SObject record, String query) {
        Map<String, Object> recordFieldMap = record.getPopulatedFieldsAsMap();
        for(String fieldName : recordFieldMap.keySet()){
            Object fieldValue = recordFieldMap.get(fieldName);
            Boolean fieldNeedsQuotes = ListigaListorController.typeNeedsQuotes.get(getType(fieldValue));
            if(fieldNeedsQuotes){
                query = query.replaceAll('\\$record\\.'+fieldName, '\''+String.valueOf(fieldValue)+'\'');
            } else{
                query = query.replaceAll('\\$record\\.'+fieldName, String.valueOf(fieldValue));
            }
        }
        return query;
    }

    static SObject getMainRecord(String query, String recordId, String objectApiName) {
        Pattern p = Pattern.compile ('\\$record\\.([\\w]+)');
        Matcher pm = p.matcher(query);
        List<String> recordFields = new List<String>();
        while(pm.find()) {
            recordFields.add(pm.group(1));
        }
        if(!recordFields.contains('Name')) {
            recordFields.add('Name');
        }
        String recordQuery = 'SELECT '+String.join(recordFields, ', ')+' FROM '+objectApiName+' WHERE Id = \''+recordId +'\' LIMIT 1';
        System.debug('record QUery '+recordQuery);
        return  Database.query(recordQuery);
    }

    @AuraEnabled
    public static void updateRecords(List<SObject> sObjList, String updateObjStr, String objectName) {
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
                            List<Integer> timeComponent = new List<Integer>();
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

    public class FieldInfo {
        @AuraEnabled public String label;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String dataType;
        @AuraEnabled public Boolean updateable;
        @AuraEnabled public Boolean sortable;
    }


    public class DataTable {
        @AuraEnabled public List<Map<String, Object>> rows;
        @AuraEnabled public List<Column> columns;
        @AuraEnabled public String objectPluralLabel;
        @AuraEnabled public String recordName;
    }
 
    public class FieldValuePair {
        @AuraEnabled public String field;
        @AuraEnabled public Object value;
    }
    public class Column {
        @AuraEnabled public String label;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean editable;
        @AuraEnabled public Boolean sortable;
        @AuraEnabled public TypeAttributes typeAttributes;

        public Column() {}

        public Column(String label, String fieldName, String type, Boolean editable, Boolean sortable, TypeAttributes typeAttributes) {
            this.label = label;
            this.fieldName = fieldName;
            this.type = type;
            this.editable = editable;
            this.sortable = sortable;
            this.typeAttributes = typeAttributes;
        }
      
    }

    public class TypeAttributes  {
        @AuraEnabled public List<Actions> rowActions;
        @AuraEnabled public String placeholder;
        @AuraEnabled public Column uniqueId; //{ fieldName: 'Id' }, //pass Id of current record to lookup for context
        @AuraEnabled public String objectX; // object name reserved, replace in javascript
        @AuraEnabled public String icon; 
        @AuraEnabled public String label; 
        @AuraEnabled public String displayFields; 
        @AuraEnabled public String displayFormat; 
        @AuraEnabled public String filters; 

        public TypeAttributes() {}
        public TypeAttributes(List<String> rowActions) {
            List<Actions> actionsList = new List<Actions>();
            for(String action : rowActions) {
                actionsList.add(new Actions(action, action.toLowerCase()));
            }
            this.rowActions = actionsList;
        }
    }
    public class Actions {
        @AuraEnabled public String label;
        @AuraEnabled public String name;
        
        public Actions(String label, String name) {
            this.label = label;
            this.name = name;
        }
    }

}