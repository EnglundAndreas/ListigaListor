public with sharing class ListigaListorController {
    public static String defaultSortOrder = ' ORDER BY CreatedDate DESC';
    @AuraEnabled
    public String relatedObjSeparator = '_relobj_';
    public class InvalidInputException extends Exception {}

    @AuraEnabled(cacheable=true)
     public static DataTableWrapper.DataTable getRecordsByQuery(
        String query,
        String recordId,
        String objectApiName,
        String rowActions,
        Integer maxColumns,
        Integer maxRows,
        String columnLabels
    ) {
        query = query.toLowerCase();
        validateQuerySyntax(query);
        String parentFieldName = getParentFieldName(query);
        SObject record = getMainRecord(query, recordId, objectApiName);
        query = setQuerySelectRecordFields(record, query);
        // if(String.isNotBlank(lastRowRecordId)) {
        //     query = setQueryLastRowRecordId(query, lastRowRecordId);
        // }

        if(!query.contains('order by')) {
            query += defaultSortOrder;
        }
        // } else if(lastRowRecordId != null) { // Override sort order if loading more records
        //     query += defaultSortOrder;
        // }

        String mainObjectName = getObjectName(query);
        List<String> fieldNames = getFieldsFromQuery(query);
        DescribeSObjectResult mainObjInfo = ListigaListorUtils.getSObjectInfo(mainObjectName);
        Map<String, DescribeFieldResult> fieldInfoMap = ListigaListorUtils.getFieldInfoMap(fieldNames, mainObjInfo);
        query = addRelationNamesToQuery(query, fieldInfoMap);
        query += ' nulls last';

        System.debug('transformed query'+ query);
        List<SObject> records = Database.query( query );

        System.debug('result from query '+records);

        DataTableWrapper.DataTable dataTable = new DataTableWrapper.DataTable();
        dataTable.objectApiName = mainObjectName;
        dataTable.parentObjectPluralLabel = ListigaListorUtils.getSObjectInfo(objectApiName).getLabelPlural();
        dataTable.objectPluralLabel = mainObjInfo.getLabelPlural();
        dataTable.recordName = record != null ? String.valueOf(record.get('name')) : null;
        dataTable.parentFieldName = parentFieldName;
        dataTable.icon = ListigaListorUtils.getIconForObject(mainObjectName);
        dataTable.rows = getRows(records, fieldInfoMap, maxRows);
        dataTable.numberOfRows = records.size();
        dataTable.columns = getColumns(fieldInfoMap, rowActions, maxColumns, columnLabels);
        return dataTable;
    }
    @TestVisible
    static String getObjectName(String query) {
        if(query.contains('where')) {
            return query.substringBetween('from ', ' where').trim();
        }
        return query.substringAfter('from ').substringBefore(' ').trim();
    }
    @TestVisible
    static void validateQuerySyntax(String query){
        try{
            Database.getQueryLocator(query);
        }catch(QueryException e){
            throw  new InvalidInputException('Invalid query syntax');
        }
    }

    static List<DataTableWrapper.Column> getColumns(Map<String, DescribeFieldResult> fieldInfoMap, String rowActions, Integer maxColumns, String columnLabels) {
        List<DataTableWrapper.Column> columns = new List<DataTableWrapper.Column>();
        List<String> columnLabelsList = new List<String>();
        Boolean useCustomLabels = false;
        if(String.isNotBlank(columnLabels)) {
            columnLabelsList = columnLabels.trim().split(',');
            if(columnLabelsList.size() != fieldInfoMap.keySet().size()) {
                throw new InvalidInputException('Please enter an equal amount of custom column labels as fields');
            }
            useCustomLabels = true;
        }
        Integer counter = 0;
        for(String field : fieldInfoMap.keySet()) {
            if(maxColumns != null && counter == maxColumns) break;
            DataTableWrapper.Column col = new DataTableWrapper.Column();
            String label;
            DescribeFieldResult fieldInfo = fieldInfoMap.get(field);
            Boolean relationField = field.contains('.');
            if(relationField) {
                String relObjname = field.substring(0, field.indexOf('.'));
                String relFieldName = field.substring(field.indexOf('.')+1);
                if(relObjname.contains('__r')) {
                    relObjname = relObjname.replace('__r', '__c');
                }
                label = useCustomLabels ? columnLabelsList.get(counter) : fieldInfo.getLabel();
                if(fieldInfo.getRelationshipName() != null) {
                   col = col.getRecordLinkColumn(field, label);
                } else {
                    col.label = label;
                    col.fieldName = field;
                }
            } else {
                label = useCustomLabels ? columnLabelsList.get(counter) : fieldInfo.getLabel();
                if(field.toLowerCase() == 'id' || fieldInfo.getRelationshipName() != null) {
                    col = col.getRecordLinkColumn(field, label);
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

        if(String.isNotBlank(rowActions)) {
            DataTableWrapper.Column actionsCol = new DataTableWrapper.Column();
            actionsCol.type = 'action';
            actionsCol.typeAttributes = new DataTableWrapper.TypeAttributes(rowActions);
            columns.add(actionsCol);
        }

        return columns;
    }

    static List<Map<String, Object>> getRows(List<SObject> records, Map<String, DescribeFieldResult> fieldInfoMap, Integer maxRows) {
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        Integer rowCounter = 0;
        for(SObject record : records ) {
            if(maxRows != null && rowCounter == maxRows) break;
            Map<String, Object> row = new Map<String, Object>();
            String relObjname;
            String relFieldName;
            Object fieldValue;
            for(String fieldName : fieldInfoMap.keySet()) {
                DescribeFieldResult fieldInfo = fieldInfoMap.get(fieldName);
                if(fieldName.contains('.')) { // Relation field
                    relObjname = fieldName.substring(0, fieldName.indexOf('.'));
                    relFieldName = fieldName.substring(fieldName.indexOf('.')+1);
                    SObject sObj = record.getSObject(relObjname);
                    if(sObj != null) {
                        fieldValue = sObj.get(relFieldName);
                        // Example: "Account.Id" Link to record with "Account.Name" as displayed value
                        if(fieldInfo.getRelationshipName() != null) {
                            setLinkRow(row, sObj, fieldName, fieldValue);
                        }
                    }
                } else { // Regular field on main object
                    fieldValue = record.get(fieldName);
                    String lookupName = fieldInfo.getRelationshipName();
                    Boolean isLookupField = lookupName != null;
                    if(fieldName.equalsIgnoreCase('id')) {
                        setLinkRow(row, record, fieldName, fieldValue);
                    } else if(isLookupField) {
                        SObject sObj = record.getSObject(lookupName);
                        if(sObj != null) {
                            setLinkRow(row, sObj, fieldName, fieldValue);
                        }
                    }
                }
                row.put(fieldName, fieldValue);
            }
            row.put('id', record.Id);
            row.put('name', record.get('name'));
            rows.add(row);
            rowCounter++;
        }
        return rows;
    }

    static void setLinkRow(Map<String, Object> row, SObject record, String fieldName, Object fieldValue) {
        row.put(fieldName+'Link', '/'+fieldValue);
        row.put(fieldName+'Label', record.get('name'));
    }

    static List<String> getFieldsFromQuery(String query) {
        List<String> fields = new List<String>();
        for(String field : query.substringBetween('select', 'from').split(',')) {
            fields.add(field.trim());
        }
        return fields;
    }

    static String addRelationNamesToQuery(String query, Map<String, DescribeFieldResult> fieldInfoMap) {
        List<String> fields = new List<String>();
        String selectFields = query.substringBetween('select', 'from').trim();
        String newSelectFields = selectFields;
        for(String fieldName : selectFields.split(',')) {
            fieldName = fieldName.trim();
            DescribeFieldResult fieldInfo = fieldInfoMap.get(fieldName);
            if(fieldName.contains('.')) {
                String relObjname = fieldName.substring(0, fieldName.indexOf('.'));
                String relFieldName = fieldName.substring(fieldName.indexOf('.')+1);
            }
            String relObjName = fieldInfo.getRelationshipName();
            if(relObjName != null && !newSelectFields.containsIgnoreCase(relObjName+'.name')) {
                newSelectFields += ', '+relObjName+'.name ';
            }
        }
        Boolean firstFieldIsNotName = newSelectFields.substringBefore(',').trim() != 'name' && newSelectFields !='name';
        if(!newSelectFields.containsIgnoreCase(' name') && firstFieldIsNotName) {
            newSelectFields +=', name ';
        }
        query = query.replace(selectFields, newSelectFields);
        return query;
    }

    static String setQueryLastRowRecordId(String query, String lastRowRecordId) {
        if(!query.contains('where')) {
            query += ' where id < \''+lastRowRecordId+'\'';
        } else {
            query += ' and id < \''+lastRowRecordId+'\'';
        }
        return query;
    }

    static String setQuerySelectRecordFields(SObject record, String query) {
        if(record != null) {
            Map<String, Object> recordFieldMap = record.getPopulatedFieldsAsMap();
            for(String fieldName : recordFieldMap.keySet()){
                Object fieldValue = recordFieldMap.get(fieldName);
                Boolean fieldNeedsQuotes = ListigaListorUtils.typeNeedsQuotes.get(ListigaListorUtils.getType(fieldValue));
                if(fieldNeedsQuotes){
                    query = query.replaceAll('\\$record\\.'+fieldName, '\''+String.valueOf(fieldValue)+'\'');
                } else{
                    query = query.replaceAll('\\$record\\.'+fieldName, String.valueOf(fieldValue));
                }
            }
        }
        return query;
    }

    @TestVisible
    static SObject getMainRecord(String query, String recordId, String objectApiName) {
        SObject mainRecord;
        Pattern p = Pattern.compile ('\\$record\\.([\\w]+)');
        Matcher pm = p.matcher(query);
        List<String> recordFields = new List<String>();
        while(pm.find()) {
            recordFields.add(pm.group(1).toLowerCase());
        }
        if(recordFields.size() > 0) {
            if(!recordFields.contains('name')) {
                recordFields.add('name');
            }
            String recordQuery = 'select '+String.join(recordFields, ', ')+' from '+objectApiName+' where id = \''+recordId +'\' limit 1';
            mainRecord = Database.query(recordQuery);
        }
        return mainRecord;
    }

    @TestVisible
    static String getParentFieldName(String query) {
        return query.contains('= $record.id') ? query.substringBefore('= $record.id').trim().substringAfterLast(' ') : null;
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

}