public with sharing class ListigaListorController {
    public static Integer loadLimit = 50;
    public static String defaultSortOrder = ' ORDER BY CreatedDate DESC';
    @AuraEnabled
    public String relatedObjSeparator = '_relobj_';

    // public static DataTable getRecordsByQuery(  String query,
    // String recordId,
    // String objectApiName,
    // String rowActions,
    // Integer maxColumns,
    // Integer maxRows,
    // String columnLabels) {
    @AuraEnabled(cacheable=true)
     public static DataTable getRecordsByQuery(
        String query,
        String recordId,
        String objectApiName,
        String rowActions,
        Integer maxColumns,
        Integer maxRows,
        String columnLabels,
        String lastRowRecordId,
        Boolean fullView
    ) {
        System.debug('this is query '+query);
        System.debug('last Row RecId'+lastRowRecordId);
        String parentFieldName = getParentFieldName(query);
        SObject record = getMainRecord(query, recordId, objectApiName);
        query = setQuerySelectRecordFields(record, query);

        if(String.isNotBlank(lastRowRecordId)) {
            query = setQueryLastRowRecordId(query, lastRowRecordId);
        }
        if(fullView) {
            maxRows = 10;
        }
        if(!query.contains('ORDER BY')) {
            query += defaultSortOrder;
        }

        String mainObjectName = getObjectName(query);
        System.debug('<< mainObjectInfo '+mainObjectName );
        List<String> fieldNames = getFieldsFromQuery(query);
        DescribeSObjectResult mainObjInfo = getSObjectInfo(mainObjectName);
        Map<String, DescribeFieldResult> fieldInfoMap = getFieldInfoMap(fieldNames, mainObjInfo);
        query = addRelationNamesToQuery(query, fieldInfoMap);
        query += ' NULLS LAST';
        System.debug('transformed query'+ query);
        List<SObject> records = Database.query( query );

        System.debug('result from query '+records);

        DataTable dataTable = new DataTable();
        dataTable.objectApiName = mainObjectName;
        dataTable.parentObjectPluralLabel = getSObjectInfo(objectApiName).getLabelPlural();
        dataTable.objectPluralLabel = mainObjInfo.getLabelPlural();
        dataTable.recordName = record != null ? String.valueOf(record.get('Name')) : null;
        dataTable.parentFieldName = parentFieldName;
        dataTable.icon = getIconForObject(mainObjectName);
        dataTable.numberOfRows = records.size();
        dataTable.rows = getRows(records, fieldInfoMap, maxRows);
        System.debug('<< ROWS count '+dataTable.rows.size());
        dataTable.columns = getColumns(fieldInfoMap, rowActions, maxColumns, columnLabels);
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
        return query.substringAfter('FROM ').substringBefore(' ').trim();
    }

    static List<Column> getColumns(Map<String, DescribeFieldResult> fieldInfoMap, String rowActions, Integer maxColumns, String columnLabels) {
        List<Column> columns = new List<Column>();
        List<String> columnLabelsList = new List<String>();
        Boolean useCustomLabels = false;
        if(String.isNotBlank(columnLabels)) {
            columnLabelsList = columnLabels.trim().split(',');
            if(columnLabelsList.size() != fieldInfoMap.keySet().size()) {
                throw new InvalidInputException('Please enter an equal amount of custom column labels as fields');
            }
            useCustomLabels = true;
        }
        Integer counter = 1;
        for(String field : fieldInfoMap.keySet()) {
            if(maxColumns != null && counter == maxColumns) break;
            Column col = new Column();
            String label;
            DescribeFieldResult fieldInfo = fieldInfoMap.get(field);
            Boolean relationField = field.contains('.');
            if(relationField) {
                String relObjname = field.substring(0, field.indexOf('.'));
                String relFieldName = field.substring(field.indexOf('.')+1);
                if(relObjname.contains('__r')) {
                    relObjname = relObjname.replace('__r', '__c');
                }
                label = useCustomLabels ? columnLabelsList.get(counter-1) : fieldInfo.getLabel();
                if(fieldInfo.getRelationshipName() != null) {
                   col = getRecordLinkColumn(field, label);
                } else {
                    col.label = label;
                    col.fieldName = field;
                }
            } else {
                label = useCustomLabels ? columnLabelsList.get(counter-1) : fieldInfo.getLabel();
                if(field.toLowerCase() == 'id' || fieldInfo.getRelationshipName() != null) {
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
        if(String.isNotBlank(rowActions)) {
            Column actionsCol = new Column();
            // Det här är påbörjad kod för en knapp istället för dropdown actions
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
            //actionsCol.rowActions = typeAttr;
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
            for(String fieldName : fieldInfoMap.keySet()) {
                String relObjname;
                String relFieldName;
                Object fieldValue;
                DescribeFieldResult fieldInfo = fieldInfoMap.get(fieldName);
                if(fieldName.contains('.')) { // Relation field
                    relObjname = fieldName.substring(0, fieldName.indexOf('.'));
                    relFieldName = fieldName.substring(fieldName.indexOf('.')+1);
                    SObject sObj = record.getSObject(relObjname);
                    System.debug('sObj '+sObj + ' rec '+ record + ' full field '+fieldName + ' rel FIeld '+relFieldName);
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
            row.put('Id', record.Id);
            row.put('Name', record.get('Name'));
            rows.add(row);
            rowCounter++;
        }
        return rows;
    }

    static void setLinkRow(Map<String, Object> row, SObject record, String fieldName, Object fieldValue) {
        row.put(fieldName+'Link', '/'+fieldValue);
        row.put(fieldName+'Label', record.get('Name'));
    }

    // Returns map with field information for every given field as in query (Account.Type gets mapped to field info for Type on Account)
    static Map<String, DescribeFieldResult> getFieldInfoMap(List<String> fieldNames, DescribeSObjectResult mainObjectInfo) {
        Map<String, DescribeFieldResult> fieldInfoMap = new Map<String,DescribeFieldResult> ();
        Map<String, SObjectField> mainObjectfieldMap = mainObjectInfo.fields.getMap();
        Map<String, Map<String, SObjectField>> relObjectFieldsMap = new Map<String, Map<String, SObjectField>>();
        Set<String> relatedObjectNames = new Set<String>();
        for(String fieldName : fieldNames) {
            if(fieldName.contains('.')){
                String relObjname = fieldName.substring(0, fieldName.indexOf('.'));
                if(!relatedObjectNames.contains(relObjName)) {
                    relatedObjectNames.add(relObjName);
                }
            }
        }
        for(String relObjName : relatedObjectNames) {
            relObjectFieldsMap.put(relObjName, getSObjectInfo(relObjName).fields.getMap());
        }
        for(String fieldName : fieldNames) {
            DescribeFieldResult fieldInfo;
            if(fieldName.contains('.')){
                String relObjname = fieldName.substring(0, fieldName.indexOf('.'));
                String relFieldName = getRelationFieldRecursive(fieldName);
                fieldInfo = relObjectFieldsMap.get(relObjName).get(relFieldName).getDescribe();
            } else {
                fieldInfo = mainObjectfieldMap.get(fieldName).getDescribe();
            }
            fieldInfoMap.put(fieldName, fieldInfo);
        }
        return fieldInfoMap;
    }

    static String getRelationFieldRecursive(String fieldName) {
        if(fieldName.contains('.')) {
            fieldName = getRelationFieldRecursive(fieldName.substring(fieldName.indexOf('.')+1));
        }
        return fieldName;
    }


    static Column getRecordLinkColumn(String field, String columnLabel) {
        Column col = new Column();
        col.label = columnLabel;
        col.fieldName = field;
        col.type = 'url';
        col.editable = false;
        col.sortable = false;

        TypeAttributes typeAttr = new TypeAttributes();
        typeAttr.label = new Map<String,String>{'fieldName' => field+'Label'};
        typeAttr.value = new Map<String,String>{'fieldName' => field+'Link'};
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

    static String addRelationNamesToQuery(String query, Map<String, DescribeFieldResult> fieldInfoMap) {
        List<String> fields = new List<String>();
        String selectFields = query.substringBetween('SELECT', 'FROM').trim();
        String newSelectFields = selectFields;
        for(String fieldName : selectFields.split(',')) {
            fieldName = fieldName.trim();
            DescribeFieldResult fieldInfo = fieldInfoMap.get(fieldName);
            if(fieldName.contains('.')) {
                String relObjname = fieldName.substring(0, fieldName.indexOf('.'));
                String relFieldName = fieldName.substring(fieldName.indexOf('.')+1);
            }
            String relObjName = fieldInfo.getRelationshipName();
            if(relObjName != null && !newSelectFields.containsIgnoreCase(relObjName+'.Name')) {
                newSelectFields += ', '+relObjName+'.Name ';
            }
        }
        Boolean firstFieldIsNotName = newSelectFields.substringBefore(',').trim() != 'Name' && newSelectFields !='Name';
        if(!newSelectFields.containsIgnoreCase(' Name') && firstFieldIsNotName) {
            newSelectFields +=', Name ';
        }
        query = query.replace(selectFields, newSelectFields);
        return query;
    }

    static String setQueryLastRowRecordId(String query, String lastRowRecordId) {
        if(!query.contains('WHERE')) {
            query += ' WHERE Id > :lastRowRecordId';
        } else {
            query += ' AND Id > :lastRowRecordId';
        }
        //query += lastRowRecordId;
        return query;
    }

    static String setQuerySelectRecordFields(SObject record, String query) {
        if(record != null) {
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
        }
        return query;
    }

    static SObject getMainRecord(String query, String recordId, String objectApiName) {
        SObject mainRecord;
        Pattern p = Pattern.compile ('\\$record\\.([\\w]+)');
        Matcher pm = p.matcher(query);
        List<String> recordFields = new List<String>();
        while(pm.find()) {
            recordFields.add(pm.group(1));
        }
        if(recordFields.size() > 0) {
            if(!recordFields.contains('Name')) {
                recordFields.add('Name');
            }
            String recordQuery = 'SELECT '+String.join(recordFields, ', ')+' FROM '+objectApiName+' WHERE Id = \''+recordId +'\' LIMIT 1';
            mainRecord = Database.query(recordQuery);
        }
        return mainRecord;
    }

    static String getParentFieldName(String query) {
        return query.contains('= $record.Id') ? query.substringBefore('= $record.Id').trim().substringAfterLast(' ') : null;

    }

        /***
     * Explores the schema of the soject passed in and finds lightning icon style and image url for sObject
     * If nothing is found, defaults to the custom icon
     *
     * @param   sObjectTypeName       the sObject to find the icon for
     * @return  Map<String,String>    Map of properties about the icon to be consumed by the front end.
     *                                Right now, returns values for keys: iconStyle,iconURL
     */
    static Map<String,String> getIconForObject(String sObjectName) {
        String iconStyle;
        String iconURL;
        String iconTag;
        Map<String, String> iconPropertyMap = new Map<String, String>();
        List<Schema.DescribeTabSetResult> tabSetDesc = Schema.describeTabs();
        List<Schema.DescribeTabResult> tabDesc = new List<Schema.DescribeTabResult>();
        List<Schema.DescribeIconResult> iconDesc = new List<Schema.DescribeIconResult>();

        for(Schema.DescribeTabSetResult tsr : tabSetDesc){
        tabDesc.addAll(tsr.getTabs());
        }
        for(Schema.DescribeTabResult tr : tabDesc) {
            if( sObjectName == tr.getSobjectName() ) {
                system.debug(tr.getIcons());
                if(!tr.getIcons().isEmpty()){
                    iconDesc.addAll(tr.getIcons());
                }else{
                    if( tr.isCustom() == true ) {
                        iconStyle = 'slds-icon-standard-custom';
                        iconURL   = '/img/icon/t4v35/standard/custom_120.png';
                    } else {
                        iconStyle = 'slds-icon-standard-' + sObjectName.toLowerCase();
                        iconURL   = '/img/icon/t4v35/standard/' + sObjectName.toLowerCase() + '_120.png';
                    }
                }
            }
        }
        for (Schema.DescribeIconResult ir : iconDesc) {
            if(ir.getTheme() =='custom' && !ir.getContentType().startsWith('image/svg')){//custom icon thats not an svg
                iconTag   = 'custom';
                iconURL   = ir.getURL();
                iconStyle = 'slds-icon-standard-custom';
                break;
            }else if(ir.getWidth() == 120 && ir.getTheme() =='theme4' && ir.getContentType() == 'image/png'){//large lightning icon image
                if(ir.getURL().contains('/custom/')){ //Icon is from the Custom Sprite
                    iconTag    = ir.getURL().substringBetween('custom/','.png').substringBefore('_');
                    iconURL    = '/img/icon/t4v35/custom/' + iconTag + '_120.png';
                    iconStyle  = 'slds-icon-custom-'+ iconTag;
                    break;
                }else if(ir.getURL().contains('/standard/')){//Icon is from the Standard Sprite
                    iconTag    = ir.getURL().substringBetween('standard/','.png').substringBefore('_');
                    iconURL    = '/img/icon/t4v35/standard/' + iconTag + '_120.png';
                    iconStyle  = 'slds-icon-standard-'+ iconTag;
                    break;
                }
            }
        }
        //if no icons are found, just default to the Custom lightning icon
        if(iconStyle == null){
            iconStyle = 'slds-icon_small slds-icon-standard-custom';
            iconURL   = '/img/icon/t4v35/standard/custom_120.png';
            iconTag   = 'No Lightning Icon Found';
        }
        //return a map with our properties for the front end
        iconPropertyMap.put('iconStyle',iconStyle);
        iconPropertyMap.put('iconURL',  iconURL);

        return iconPropertyMap;
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
        if(o instanceof Time)               return 'Time';
        if(o instanceof Datetime)           return 'Datetime';
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


    public class DataTable {
        @AuraEnabled public List<Map<String, Object>> rows;
        @AuraEnabled public List<Column> columns;
        @AuraEnabled public String parentObjectPluralLabel;
        @AuraEnabled public String objectPluralLabel;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String recordName;
        @AuraEnabled public String parentFieldName;
        @AuraEnabled public Integer numberOfRows;
        @AuraEnabled public Map<String, String> icon;
    }

    public class DataTableInput {
        @AuraEnabled public String query;
        @AuraEnabled public String recordId;
        @AuraEnabled public String objectApiName;
        @AuraEnabled public String rowActions;
        @AuraEnabled public Integer maxColumns;
        @AuraEnabled public Integer maxRows;
        @AuraEnabled public String columnLabels;
        @AuraEnabled public String lastRowRecordId;
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
        public TypeAttributes(String rowActions) {
            List<String> rowActionsList = rowActions.split(',');
            List<Actions> actionsList = new List<Actions>();
            for(String action : rowActionsList) {
                actionsList.add(new Actions(action.trim(), action.trim().toLowerCase()));
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