Include dc.openapi.common.macro

/// Load a specification and convert in OpenAPI versoin 3 if needed
Class dc.openapi.common.SpecificationLoader
{

/// Return the swagger specification in a dynamic object <br/>
/// spec argument could be a stream, a dynamic object or an URL.<br/>
ClassMethod AbstractSpecLoader(
	spec,
	ByRef sc As %Status = {$$$OK}) As %DynamicObject
{
    Set returnSpec = "", sc = $$$OK

    Try{

        If $ISOBJECT(spec), spec.%IsA("%DynamicObject") {   ; spec is already a dynamic object

            Set returnSpec = {}.%FromJSON(spec.%ToJSON())

        } ElseIf $ISOBJECT(spec), spec.%IsA("%Stream.Object") { ; spec is a stream convert in json if it's a yaml format
            
            Set returnSpec = $SELECT(..isYAML(spec): ..convertYAMLToJSON( spec, .sc), 1: {}.%FromJSON(spec))

            If $$$ISERR(sc) $$$ThrowStatus(sc)
        
        } ElseIf $$$LOWER($EXTRACT(spec, 1, 4)) = "http" {  ; it's an URL download and convert to json if it's a yaml format
            
            Set returnSpec = ..loadSpecFromUrl(spec), fixServerURL = 1

        } Else {   ; it's file path

            Set returnSpec = ..loadSpecFromFile(spec)

        }

        If '$ISOBJECT(returnSpec) || 'returnSpec.%IsA("%DynamicObject") $$$ThrowStatus($$$ERROR(5001,"No Specification found."))

        ; Now check if it's a OpenAPI 3 specification and convert if it's a previous version.

        If returnSpec.%IsDefined("swagger") {
            ; This is not an OpenAPI 3 specification
            ; The library does not support only version 3
            ; We attempt to convert this specification to version 3 https://converter.swagger.io/

            $$$zlog("Not an OpenAPI V3 specification, try to convert using swagger converter... ")

            Set webConverter = ##class(dc.swaggerconverter.WebConverter).%New()

            ; If the spec is an url we convert later after resolve external references
            If $$$LOWER($EXTRACT(spec, 1, 4)) '= "http" {
                Set webConverter.specification = returnSpec
                $$$TOE(sc, webConverter.Convert(.OpenAPIV3))
            }

            Set returnSpec = OpenAPIV3

            $$$zlog("Conversion to version 3 done.")
        }

        $$$zlog("* Parse the definition with flatten=true to simplify the structure ... ")

        Set webValidator = ##class(dc.swaggervalidatorcli.WebSwaggerValidator).%New()
        Set OpenAPIV3 = ""
        Set queryParameters("flatten")="true"

        If $$$LOWER($EXTRACT(spec, 1, 4)) = "http" {
            ; Add external references support
            Set queryParameters("resolveFully")="true"
            Set queryParameters("validateExternalRefs")="true"
            Set:$$$LOWER($EXTRACT(spec, 1, 4))="http" queryParameters("url") = spec
            Set sc = webValidator.ParseByUrl(.queryParameters, .OpenAPI)

            If $$$ISERR(sc) $$$ThrowStatus(sc)

            If returnSpec.%IsDefined("swagger") { ; Not V3, we need to convert.
                Set webConverter.specification = OpenAPI
                $$$TOE(sc, webConverter.Convert(.OpenAPIV3))
            } Else { ; Ok it's already V3
                Set OpenAPIV3 = OpenAPI
            }

        } Else {
            Set webValidator.specification = returnSpec
            Set sc = webValidator.Parse(.queryParameters, .OpenAPIV3)
        }

        If $$$ISERR(sc) $$$ThrowStatus(sc)

        Set returnSpec = OpenAPIV3

        $$$zlog("= Parse the definition with flatten=true done ...")

        If '$Isobject(returnSpec) || ( $Extract(returnSpec.openapi) '= "3" ) $$$ThrowStatus($$$ERROR($$$GeneralError,"Not an OpenAPI version 3 specification."))

        If $Get(fixServerURL) = 1 {
        
            Do ##class(%Net.URLParser).Decompose(spec, .components)
            Set returnSpec.servers.%Get(0).url = $GET(components("scheme")) _ "://" 
                ;_ $SELECT($DATA(components("username"), user): user _ ":" _ $GET(components("password")) _"@",1:"") 
                _ $GET(components("host"))
                _ $SELECT($DATA(components("port"), port): ":"_port,1:"") 
                _ returnSpec.servers.%Get(0).url
        
        }

    } Catch(ex) {
        Set sc = ex.AsStatus()
        Set msg = $SYSTEM.Status.GetOneErrorText(sc)
        ;If msg [ "Parsing err" Set sc = $$$ERROR($$$GeneralError, "Only JSON format is supported.")
        $$$zlog(msg)
    }

    Return returnSpec
}

ClassMethod isYAML(stream As %Stream.Object) As %Boolean
{
    Do stream.Rewind()
    Set buffer = $ZSTRIP(stream.Read(),"<W")
    Do stream.Rewind()
    Quit ($EXTRACT(buffer) '= "{") && ((buffer [ "swagger:")||(buffer [ "openapi:"))
}

/// Convert YAML to JSON
ClassMethod convertYAMLToJSON(
	stream As %Stream.Object,
	Output sc As %Status) As %DynamicObject
{
    Set lt = stream.Read()

    // Make sure that the lineTerminator is also set if there are no CRLF line separators
	If lt [ $CHAR(13,10)
    {
        Set stream.LineTerminator = $CHAR(13,10)
    }
    Else
    {
        Set stream.LineTerminator = $CHAR(10)
    }

    Do stream.Rewind()
    Quit ##class(YAML.Utils).StreamToJSON(stream, .sc)
}

ClassMethod loadSpecFromUrl(url As %String) As %DynamicObject
{
    Do ##class(%Net.URLParser).Decompose(url, .components)

    Set request = ##class(%Net.HttpRequest).%New()
    Set request.Server = $GET(components("host"))
    Set:$DATA(components("port"), port) request.Port = port
    Set:$DATA(components("scheme"), scheme) request.Https = $$$LOWER(scheme) = "https"
    
    If request.Https Set request.SSLConfiguration = "DefaultSSL"

    Set:$DATA(components("username"), username) request.Username = username
    Set:$DATA(components("password"), password) request.Password = password

    $$$TOE(sc, request.Send("GET", $GET(components("path") )) )
    
    If request.HttpResponse.StatusCode '= 200 {
        $$$ThrowStatus($$$ERROR(5001, "Http status code : " _ request.HttpResponse.StatusCode ))
    }

    Set stream = request.HttpResponse.Data

    Set spec = $SELECT( ..isYAML(stream) : ..convertYAMLToJSON( stream, .sc), 1: {}.%FromJSON(stream) )
    
    If $$$ISERR(sc) $$$ThrowStatus(sc)

    Return spec
}

ClassMethod loadSpecFromFile(file As %String) As %DynamicObject
{
    Set sc = $$$OK, stream = ##class(%Stream.FileCharacter).%New(), stream.Filename = file
    
    If '##class(%File).Exists(file) $$$ThrowStatus($$$ERROR($$$GeneralError,"Specification file not found : "_file))

    Set spec = $SELECT( ..isYAML(stream) : ..convertYAMLToJSON( stream, .sc), 1: {}.%FromJSON(stream) )
    
    If $$$ISERR(sc) $$$ThrowStatus(sc)

    Return spec
}

}
