public with sharing class ListigaListorController {
    public static Integer loadLimit = 50;
    public static String defaultSortOrder = ' ORDER BY CreatedDate DESC';
    @AuraEnabled
    public String relatedObjSeparator = '_relobj_';

    @AuraEnabled(cacheable=true)
    public static DataTable getRecordsByQuery(String query, String recordId, String objectApiName, Boolean enableRowActions, Integer maxColumns, String columnLabels){
        String lastRowRecordId;
        List<String> rowActions = new List<String> {'Edit', 'View', 'Kill'};
        System.debug('this is query '+query);
        SObject record = getMainRecord(query, recordId, objectApiName);
        query = setQuerySelectRecordFields(record, query);

        if(String.isNotBlank(lastRowRecordId)) {
            query = setQueryLastRowRecordId(query, lastRowRecordId);
        }
        if(!query.contains('ORDER BY')) {
            query += defaultSortOrder;
        }
        List<String> fieldNames = getFieldsFromQuery(query);
        query = addRelationNamesToQuery(query);
        query += ' NULLS LAST LIMIT '+loadLimit;

        List<SObject> records = Database.query( query );
        System.debug('result from query '+records);

        String mainObjectName = getObjectName(query);

        DataTable dataTable = new DataTable();
        dataTable.objectApiName = mainObjectName;
        dataTable.objectPluralLabel = getSObjectInfo(objectApiName).getLabelPlural();
        dataTable.recordName = String.valueOf(record.get('Name'));
        dataTable.rows = getRows(records, fieldNames, mainObjectName);
        dataTable.columns = getColumns(fieldNames, rowActions, mainObjectName, enableRowActions, maxColumns, columnLabels);
        return dataTable;
    }

    static DescribeFieldResult getFieldInfo(Map<String, SObjectField> objectFieldMap, String fieldName) {
       return objectFieldMap.get(fieldName).getDescribe();
    }

    static DescribeSObjectResult getSObjectInfo(String objectName) {
        System.debug('getSObjectInfo '+objectName + ' null? '+Schema.getGlobalDescribe().get(objectName).getDescribe());
        return Schema.getGlobalDescribe().get(objectName).getDescribe();
    }

    static String getObjectName(String query) {
        if(query.contains('WHERE')) {
            return query.substringBetween('FROM ', ' WHERE').trim();
        }
        return query.substringBetween('FROM ', ' ').trim();
    }

    static List<Column> getColumns(List<String> fieldNames, List<String> rowActions, String mainObjectName, Boolean enableRowActions, Integer maxColumns, String columnLabels) {
        System.debug('<< getColumns START');
        List<Column> columns = new List<Column>();
        Map<String, SObjectField> fieldInfoMap = getSObjectInfo(mainObjectName).fields.getMap();
        List<String> columnLabelsList = new List<String>();
        Boolean useCustomLabels = false;
        if(String.isNotBlank(columnLabels)) {
            columnLabelsList = columnLabels.split(',');
            if(columnLabelsList.size() != fieldNames.size()) {
                throw new InvalidInputException('Please enter an equal amount of custom column labels as fields');
            }
            useCustomLabels = true;
        }
        Integer counter = 1;
        for(String field : fieldNames) {
            if(maxColumns != null && counter == maxColumns) break;
            Column col = new Column();
            String label;
            DescribeFieldResult fieldInfo;
            Boolean relationField = field.contains('.');
            if(relationField) {
                String relObjname = field.substring(0, field.indexOf('.'));
                String relFieldName = field.substring(field.indexOf('.')+1);
                if(relObjname.contains('__r')) {
                    relObjname = relObjname.replace('__r', '__c');
                }
                Map<String, SObjectField> relObjFieldMap = getSObjectInfo(relObjname).fields.getMap();
                fieldInfo = getFieldInfo(relObjFieldMap, relFieldName);
                label = useCustomLabels ? columnLabelsList.get(counter-1) : fieldInfo.getLabel();
                if(relFieldName.toLowerCase() == 'name') {
                   col = getRecordLinkColumn(field, label);
                } else {
                    col.label = label;
                    col.fieldName = field;
                }
            } else {
                fieldInfo = getFieldInfo(fieldInfoMap, field);
                label = useCustomLabels ? columnLabelsList.get(counter-1) : fieldInfo.getLabel();
                if(field.toLowerCase() == 'name') {
                    col = getRecordLinkColumn(field, label);
                } else {
                    col.label = label;
                    col.fieldName = field;
                    col.type = fieldInfo.getType().name().toLowerCase();
                    col.editable = !relationField && fieldInfo.isUpdateable();
                    col.sortable = fieldInfo.isSortable();
                }
            }
            columns.add(col);
            counter ++;
        }
        if(enableRowActions) {
            Column actionsCol = new Column();
            //TypeAttributes typeAttr = new TypeAtt<ributes(rowActions);
                   // for(String action : rowActions) {
            //     typeAttr.put('label', action);
            //     typeAttr.put('name', action.toLowerCase());
            // } Map<String,Object> typeAttr = new Map<String, Object>();
    
            // if(rowActi<ons.size() == 1) {
            //     actionsCol.type = 'button-icon';
            //     typeAttr.put('label', rowActions[0]);
            //     typeAttr.put('name', 'utility:'+rowActions[0].toLowerCase());
            //     typeAttr.put('class', 'slds-button_icon-container slds-button_icon-x-small');
            // } else {
                actionsCol.type = 'action';
            //}
            actionsCol.typeAttributes = new TypeAttributes(rowActions);
            actionsCol.type = 'action';
            //actionsCol.rowActions = typeAttr;
            columns.add(actionsCol);
        }

        return columns;
    }


    static List<Map<String, Object>> getRows(List<SObject> records, List<String> fieldNames, String mainObjectName) {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        Map<String, SObjectField> fieldInfoMap = getSObjectInfo(mainObjectName).fields.getMap();
        Map<String, Schema.SObjectType> mapSObjects = Schema.getGlobalDescribe();
        for(SObject record : records ) {
            Map<String, Object> row = new Map<String, Object>();
            for(String fieldName : fieldNames) {
                System.debug('new loop fieldname');
                Boolean relationField = fieldName.contains('.');
                Boolean editable = !relationField;
                String relObjname;
                String relFieldName;
                Object fieldValue;
                if(relationField) {
                    relObjname = fieldName.substring(0, fieldName.indexOf('.'));
                    relFieldName = fieldName.substring(fieldName.indexOf('.')+1);
                    SObject sObj = record.getSObject(relObjname);
                    System.debug('sObj '+sObj + ' rec '+ record + ' full field '+fieldName + ' rel FIeld '+relFieldName);
                    if(sObj != null){
                        fieldValue = sObj.get(relFieldName);
                        // Example: "Account.Id" Link to record with "Account.Name" as displayed value
                        if(relFieldName.equalsIgnoreCase('name')) {
                            row.put(fieldName+'Link', '/'+sObj.get('Id'));
                            row.put(fieldName, fieldValue);
                        }
                    }
                } else {
                    fieldValue = record.get(fieldName);
                    if(fieldName.equalsIgnoreCase('name')){
                        row.put(fieldName+'Link', '/'+record.get('Id'));
                        row.put(fieldName, fieldValue);
                    }
                    row.put(fieldName, fieldValue);
                }
            }
                row.put('Id', record.Id);
            rows.add(row);
        }

        return rows;
    }


    static Column getRecordLinkColumn(String field, String columnLabel) {
        Column col = new Column();
        col.label = columnLabel;
        col.fieldName = field+'Link';
        col.type = 'url';
        col.editable = false;
        col.sortable = true;
        
        // Map<String,Object> typeAttr = new Map<String,Object>();
        // typeAttr.put('label', (Map<String,String>) new Map<String,String>{'fieldName' => field+'Label'});
        // typeAttr.put('value', (Map<String,String>) new Map<String,String>{'fieldName' => field+'Link'});
        // col.typeAttributes = typeAttr;
        TypeAttributes typeAttr = new TypeAttributes();
        typeAttr.label = new Map<String,String>{'fieldName' => field};
        typeAttr.value = new Map<String,String>{'fieldName' => field};
        col.typeAttributes = typeAttr;
        return col;
    }

    static List<String> getFieldsFromQuery(String query) {
        List<String> fields = new List<String>();
        for(String field : query.substringBetween('SELECT', 'FROM').split(',')) {
            fields.add(field.trim());
        }
        return fields;
    }

    static String addRelationNamesToQuery(String query) {
        List<String> fields = new List<String>();
        String selectFields = query.substringBetween('SELECT', 'FROM');
        String newSelectFields = query.substringBetween('SELECT', 'FROM');
        for(String fieldName : selectFields.split(',')) {
            if(fieldName.contains('.')) {
                String relObjname = fieldName.substring(0, fieldName.indexOf('.'));
                String relFieldName = fieldName.substring(fieldName.indexOf('.')+1);
                String relObjNameRef = relObjname + '.Id';
                if(relFieldName.equalsIgnoreCase('name') && !selectFields.contains(relObjNameRef)) {
                    newSelectFields += ', '+relObjNameRef+' ';
                }
            }
        }
        System.debug('<< addRelationNamesToQuery '+selectFields + ' replacing with '+newSelectFields);
        query = query.replace(selectFields, newSelectFields);
        return query;
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
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String recordName;
    }

    public class Column {
        @AuraEnabled public String label;
        @AuraEnabled public String fieldName;
        @AuraEnabled public String type;
        @AuraEnabled public Boolean editable;
        @AuraEnabled public Boolean sortable;
        @AuraEnabled public TypeAttributes typeAttributes;
        //@AuraEnabled public Map<String, Object> typeAttributes;
        @AuraEnabled public Map<String, Object> rowActions;
        @AuraEnabled public Map<String, Object> cellAttributes;

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
        @AuraEnabled public Object value;
        @AuraEnabled public Object label;
        @AuraEnabled public String name;
        @AuraEnabled public String iconName;
        @AuraEnabled public String iconPostion;

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

    public class InvalidInputException extends Exception {}
}