Include dc.openapi.common.macro

Class dc.openapi.common.Utils
{

ClassMethod log(msg As %String, nl As %Boolean = {$$$YES}, dtOnNL As %Boolean = {$$$YES})
{
    Quit:$Get(%zverbose)=0

    Write:nl !
    Write:nl&&dtOnNL $ZDateTime($Horolog, 3, 1), " "
    Write msg

    Quit
}

ClassMethod CreateClassDefInstance(className As %String, Output classDef As %Dictionary.ClassDefinition = "") As %Dictionary.ClassDefinition
{
    If $$$defClassDefined(className) {
        Set sc = $$Delete^%apiOBJ(className,"-d")
        If $$$ISERR(sc) Quit sc
    }

    Kill %objlasterror

    Set classDef = ##class(%Dictionary.ClassDefinition).%New(className)
	If '$IsObject(classDef) {
		Quit $Get(%objlasterror, $$$ERROR($$$FailedToCreateClass, className))
	}

    Set classDef.ProcedureBlock = $$$YES

    Quit $$$OK
}

ClassMethod FindPropertyName(classDefinition As %Dictionary.ClassDefinition, propertyName As %String) As %Dictionary.PropertyDefinition
{
    #dim property As %Dictionary.PropertyDefinition
    Set key = ""

    Set property = classDefinition.Properties.GetNext(.key)
    While key '= "" {
        
        Return:property.Name=propertyName property

        Set property = classDefinition.Properties.GetNext(.key)
    }

    Return ""
}

ClassMethod ForceNotDefinedMAXLEN(package As %String, maxLenValue As %String = "") As %Status
{
    #dim propDef As %Dictionary.PropertyDefinition
    Set sc = $$$OK, (startKey, className) = package _"."
    
    For  {
        Set className = $Order(^oddDEF(className))
        Quit:$Extract(className, 1, $LENGTH(startKey))'=startKey

        Set classDef = ##class(%Dictionary.ClassDefinition).%OpenId(className,, .scO)
        If $$$ISERR(sc) {
            Set sc = $$$ADDSC(sc, scO)
            Continue
        }

        Set key = ""
        For  {
            Set propDef = classDef.Properties.GetNext(.key)
            Quit:key=""
            If "%String,%Library.String,%VarString"[propDef.Type, propDef.Parameters.GetAt("MAXLEN") = "" {
                $$$zlog("Force " _ className _" " _ propDef.Name _" with MAXLEN=" _ maxLenValue)
                Do propDef.Parameters.SetAt(maxLenValue, "MAXLEN")
                Set sc = $$$ADDSC(sc, propDef.%Save()) 
            }
        }
    }

    Quit sc
}

ClassMethod packageExists(packageName As %String) As %Boolean
{
    Set packageList = ##class(%Dictionary.PackageDefinition).GetPackageList()
    Return ''packageList.Find($zcvt(packageName, "U"))
}

ClassMethod RemoveXDataBlock(cDef, blockName)
{
 	Set key = cDef.XDatas.FindObjectId(cDef.Name_"||"_blockName)
 	If (key'="") {
 		Set oid = cDef.XDatas.RemoveAt(key)
	}
}

ClassMethod CommonSchemaProcessForFlatteSpec(classDef As %Dictionary.ClassDefinition, propDef As %Dictionary.PropertyDefinition, schema As %DynamicObject, package As %String, specification) As %Status
{
    Set sc = $$$OK

    If schema.%IsDefined("$ref") {
        Set schema = ..GetObjectByRef(specification, schema."$ref", .refName)
        Quit:'$IsObject(schema) sc

        If schema.type = "object" {
            Set propDef.Type = package _ "." _ $$$zNormalizeClassName(refName)
            Do classDef.Properties.Insert(propDef)
            Quit sc
        }
    }

    If schema.type = "array" {

        Set propDef.Collection = "list"

        If schema.items."$ref" '="" {
            Set refObject = ..GetObjectByRef(specification, schema.items."$ref", .refName)
            Quit:'$IsObject(refObject) sc
            
            Set propDef.Type = $Select(refObject.type="object": package _ "." _ $$$zNormalizeClassName(refName), 1: $$$GetObjectScriptType(refObject.type,refObject.format))
            
        } Else {

            Set propDef.Type = $$$GetObjectScriptType(schema.items.type,schema.items.format)
        
        }
    
    } Else {
        w !,schema.type,schema.format
        Set propDef.Type = $$$GetObjectScriptType(schema.type,schema.format)
    }

    Do classDef.Properties.Insert(propDef)

    Quit sc
}

ClassMethod GetObjectByRef(specification As %DynamicObject, reference As %String, Output name As %String) As %DynamicObject
{
    /// ex reference : "#/components/schemas/model"

    Set tmpObjRef =  specification, name = $Piece(reference, "/", *)

    For i=2:1:$Length(reference, "/") {
        Set tmpObjRef = tmpObjRef.%Get($Piece(reference, "/", i))
        Quit:tmpObjRef=""
    }

    If '$ISOBJECT(tmpObjRef) $$$zlog($Char(9) _ "! Reference : """ _ reference _ """ not found.")

    Quit tmpObjRef
}

ClassMethod MergeParametersArray(from As %DynamicArray, to As %DynamicArray) As %DynamicArray
{
    #dim target As %DynamicArray = {}.%FromJSON(from.%ToJSON())

    Set names = ""
    Set iter = from.%GetIterator()
    While iter.%GetNext(.key, .parameter) {
        Set names(" "_parameter.name)=key
    }

    Set iter = to.%GetIterator()
    While iter.%GetNext(.key, .parameter) {
        Set:$Data(names(" "_parameter.name), key) del(key) = ""
        Do target.%Push(parameter)
    }

    Set key = ""
    For  {
        Set key = $Order(del(key), -1, pos)
        Quit:key=""
        Do target.%Remove(pos)
    }

    Quit target
}

}
