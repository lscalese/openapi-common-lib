Include dc.openapi.common.macro

Class dc.openapi.common.Generator
{

Parameter PKGMODEL = "model";

Parameter PKGREQUEST = "requests";

/// OpenAPI Version 3 specification.
Property spec As %DynamicObject;

/// this is the base package name where will be stored the generated classes.
Property application As %String [ Required ];

Property packageModel As %String [ Private ];

Property packageRequest As %String [ Private ];

Property superRequest As %String [ InitialExpression = "%RegisteredObject" ];

/// Helper to iterate operation object<br/>
/// the callback must be method with the parameters<br/>
/// (path As %String, pathItem As %DynamicObject, method As %String, operation As %DynamicObject)<br/>
Method IterateOnOperation(callBackMethod As %String) As %Status [ Private ]
{
    Set sc = $$$OK

    Quit:'..spec.%IsDefined("paths") sc

    Set pathIterator = ..spec.paths.%GetIterator()

    While pathIterator.%GetNext(.path, .pathItem) {
        
        Continue:'$IsObject(pathItem)

        For method = "get", "put", "post", "delete", "options", "head", "patch", "trace" {
            
            Set operation = pathItem.%Get(method)
            Continue:'$IsObject(operation)
            
            Set sc = $$$ADDSC(sc, $METHOD(##this, callBackMethod, path, pathItem, method, operation) )

        }

    }

    Quit sc
}

Method IterateOnResponses(callBackMethod As %String) As %Status [ Private ]
{
    Set sc = $$$OK

    Quit:'..spec.%IsDefined("paths") sc

    Set pathIterator = ..spec.paths.%GetIterator()

    While pathIterator.%GetNext(.path, .pathItem) {
        
        Continue:'$IsObject(pathItem)

        For method = "get", "put", "post", "delete", "options", "head", "patch", "trace" {
            
            Set operation = pathItem.%Get(method)
            Continue:'$IsObject(operation)
            
            Continue:'$IsObject(operation.responses)
            
            Set responseIterator = operation.responses.%GetIterator()

            While responseIterator.%GetNext(.response, .responseItem) {

                Set sc = $$$ADDSC(sc, $METHOD(##this, callBackMethod, path, pathItem, method, operation, response, responseItem) )

            }

        }

    }

    Quit sc
}

Method GenerateRequestClass(path As %String, pathItem As %DynamicObject, method As %String, operation As %DynamicObject) As %Status
{
    Set sc = $$$OK
    
    $$$zlog("* Generate Request class for " _path _ " "_ method _ "...")

    Do ..CheckAndGenerateOperationId(method, .operation, path)

    Set className = ..packageRequest _ "." _ $$$zNormalizeClassName(operation.operationId)
    $$$zlog($Char(9) _"Class name is " _ className)


    #dim classDef As %Dictionary.ClassDefinition
    $$$QuitOnError(##class(dc.openapi.common.Utils).CreateClassDefInstance(className, .classDef))
    Set classDef.Super = ..superRequest

    ; Create parameter URL with the path
    #dim classParameter As %Dictionary.ParameterDefinition = ##class(%Dictionary.ParameterDefinition).%New()
    Set classParameter.Name = "URL"
    Set classParameter.Default = path
    Do classDef.Parameters.Insert(classParameter)

    ; Create method parameter
    Set classParameter = ##class(%Dictionary.ParameterDefinition).%New()
    Set classParameter.Name = "METHOD"
    Set classParameter.Default = method
    Do classDef.Parameters.Insert(classParameter)

    /// Add property contentType
    Set propertyName = "%ContentType", propDef = $$$FindPropertyName(classDef, propertyName)
    Set:'$IsObject(propDef) propDef = ##class(%Dictionary.PropertyDefinition).%New(classDef.Name _ ":" _ propertyName )
    Set propDef.Type = "%String"
    $$$zlog($Char(9) _ "+ Add property " _ propertyName)
    Do classDef.Properties.Insert(propDef)

    /// Add property contentType (accept http header)
    Set propertyName = "%Consume", propDef = $$$FindPropertyName(classDef, propertyName)
    Set:'$IsObject(propDef) propDef = ##class(%Dictionary.PropertyDefinition).%New(classDef.Name _ ":" _ propertyName )
    Set propDef.Type = "%String"
    $$$zlog($Char(9) _ "+ Add property " _ propertyName)
    Do classDef.Properties.Insert(propDef)

    /// Add property contentType
    Set propertyName = "%URL", propDef = $$$FindPropertyName(classDef, propertyName)
    Set:'$IsObject(propDef) propDef = ##class(%Dictionary.PropertyDefinition).%New(classDef.Name _ ":" _ propertyName )
    Set propDef.Type = "%String", propDef.InitialExpression = "..#URL"
    $$$zlog($Char(9) _ "+ Add property " _ propertyName)
    Do classDef.Properties.Insert(propDef)

    ; If parameters array is defined in path and also in the operation,
    ; We merge these array.
    Set parameters = ..GetOperationParameters(pathItem, operation)

    Set parameterIterator = parameters.%GetIterator()
    While parameterIterator.%GetNext(.key, .parameter) {

        ; parameter is a parameter object https://swagger.io/specification/#parameter-object
        
        Set:parameter."$ref"'="" parameter = ##class(dc.openapi.common.Utils).GetObjectByRef(..spec, parameter."$ref", .name)
        
        Continue:'$IsObject(parameter)
        Continue:parameter.name=""
        Continue:parameter.in=""
        
        Set propDef = $$$FindPropertyName(classDef, $$$NormalizePropertyParamName(parameter.in_parameter.name))
        Set:'$IsObject(propDef) propDef = ##class(%Dictionary.PropertyDefinition).%New(classDef.Name _ ":" _ $$$NormalizePropertyParamName(parameter.in_parameter.name))

        Set propDef.Description = parameter.description

        If 'parameter.%IsDefined("schema") {
            Set propDef.Type = "%String"
            Do classDef.Properties.Insert(propDef)
            Continue
        }

        Set sc = $$$ADDSC(sc, ##class(dc.openapi.common.Utils).CommonSchemaProcessForFlatteSpec(classDef, propDef, parameter.schema, ..packageModel, ..spec))

    }

    If '$ISOBJECT(operation.requestBody) Quit $$$ADDSC(sc, classDef.%Save())

    Set bodyContentIterator = operation.requestBody.content.%GetIterator()
    
    While bodyContentIterator.%GetNext(.contentType, .contentTypeItem) {
        
        ;Continue:'$IsObject(contentTypeItem.schema)
        
        If 'contentTypeItem.%IsDefined("schema"){
            Set thePropType = $Select($$$LOWER(contentType)="application/json":"%DynamicObject",1:"%Stream.Object")
            Set hash = $ZCRC(thePropType, 7)
            If '$Data(tmp(hash)) {
                Set propertyName = $$$NormalizePropertyParamName("body") _ $INCREMENT(body), propDef = $$$FindPropertyName(classDef, propertyName)
                Set:'$IsObject(propDef) propDef = ##class(%Dictionary.PropertyDefinition).%New(classDef.Name _ ":" _ propertyName)
                Set propDef.Type = thePropType
                Set:operation.requestBody.required||(operation.requestBody.required="true") propDef.Required = $$$YES
                Do classDef.Properties.Insert(propDef)
                Set tmp(hash) = propDef
                Set propDef.Description = "Use this property for body content with content-type = "_contentType _".<br/>"
            } Else {
                Set tmp(hash).Description = tmp(hash).Description _ $c(13,10) 
                    _"Use this property for body content with content-type = "_contentType _".<br/>"
            }
            Continue
        }

        Set hash = $ZCRC(contentTypeItem.schema.%ToJSON(), 7)
        
       
        If $Data(tmp(hash)) {
            Set tmp(hash).Description = tmp(hash).Description _ $c(13,10) 
                _"Use this property for body content with content-type = "_contentType _".<br/>"
        } Else {
            Set propertyName = $$$NormalizePropertyParamName("body") _ $INCREMENT(body), propDef = $$$FindPropertyName(classDef, propertyName)
            Set:'$IsObject(propDef) propDef = ##class(%Dictionary.PropertyDefinition).%New(classDef.Name _ ":" _ propertyName)
            Set tmp(hash) = propDef
            Set propDef.Description = "Use this property for body content with content-type = "_contentType _".<br/>"
            Set sc = $$$ADDSC(sc, ##class(dc.openapi.common.Utils).CommonSchemaProcessForFlatteSpec(classDef, propDef, contentTypeItem.schema, ..packageModel, ..spec))
            Set:operation.requestBody.required||(operation.requestBody.required="true") propDef.Required = $$$YES
            Do classDef.Properties.Insert(propDef)
        }
    }


    Set sc = $$$ADDSC(sc, classDef.%Save())

    Quit sc
}

ClassMethod CheckAndGenerateOperationId(method As %String, operation As %DynamicObject, path As %String) As %Status
{
    If operation.operationId = "" { ; In order to ease the code generation, we generate an operationId
    
        Set operation.operationId = $$$zNormalizeClassName(path) _ $ZConvert(method, "U")
        $$$zlog($Char(9) _"! operationId field not defined, the following operationId has been auto-generated" _ operation.operationId)
    } Else {
        $$$zlog($Char(9) _"= operationId exists " _ operation.operationId)

    }

    ; force Normalize operationId
    Set operation.operationId = $$$zNormalizeClassName(operation.operationId)

    Quit $$$OK
}

ClassMethod GetOperationParameters(pathItem As %DynamicObject, operation As %DynamicObject) As %DynamicArray
{
    #dim parameters As %DynamicArray = []

    Set:$IsObject(operation.parameters) parameters = {}.%FromJSON(operation.parameters.%ToJSON())
    Set:$IsObject(pathItem.parameters)&&pathItem.parameters.%IsA("%DynamicArray") parameters = ##class(dc.openapi.common.Utils).MergeParametersArray(pathItem.parameters, parameters)
    
    Quit parameters
}

}
