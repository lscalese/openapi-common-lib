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

}
