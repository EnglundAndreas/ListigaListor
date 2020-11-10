public class ListigaListorUtils {
    // Returns map with field information for every given field as in query (Account.Type gets mapped to field info for Type on Account)
    public static Map<String, DescribeFieldResult> getFieldInfoMap(List<String> fieldNames, DescribeSObjectResult mainObjectInfo) {
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

    public static DescribeFieldResult getFieldInfo(Map<String, SObjectField> objectFieldMap, String fieldName) {
        return objectFieldMap.get(fieldName).getDescribe();
    }
 
    public static DescribeSObjectResult getSObjectInfo(String objectName) {
         return Schema.getGlobalDescribe().get(objectName).getDescribe();
    }

    /***
     * Explores the schema of the soject passed in and finds lightning icon style and image url for sObject
     * If nothing is found, defaults to the custom icon
     *
     * @param   sObjectTypeName       the sObject to find the icon for
     * @return  Map<String,String>    Map of properties about the icon to be consumed by the front end.
     *                                Right now, returns values for keys: iconStyle,iconURL
     */
    public static Map<String,String> getIconForObject(String sObjectName) {
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
    public static Map<String,Boolean> typeNeedsQuotes = new Map<String,Boolean>{
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