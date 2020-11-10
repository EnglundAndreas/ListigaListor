public with sharing class DataTableWrapper {
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

        public Column getRecordLinkColumn(String field, String columnLabel) {
            Column col = new Column();
            col.label = columnLabel;
            col.fieldName = field+'Link';
            col.type = 'url';
            col.editable = false;
            col.sortable = false;

            TypeAttributes typeAttr = new TypeAttributes();
            typeAttr.label = new Map<String,String>{'fieldName' => field+'Label'};
            typeAttr.tooltip = new Map<String,String>{'fieldName' => field+'Label'};
            //typeAttr.value = new Map<String,String>{'fieldName' => field+'Link'};
            col.typeAttributes = typeAttr;
            return col;
        }
    }

    public class TypeAttributes  {
        @AuraEnabled public List<Actions> rowActions;
        @AuraEnabled public Object value;
        @AuraEnabled public Object label;
        @AuraEnabled public Object tooltip;
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

}