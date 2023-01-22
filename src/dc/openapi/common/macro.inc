ROUTINE dc.openapi.common.macro [Type=INC]

#def1arg zlog(%arg)                         Do ##class(dc.openapi.common.Utils).log(%arg)
#def1arg FindPropertyName(%arg)             ##class(dc.openapi.common.Utils).FindPropertyName(%arg)
#def1arg NormalizePropertyParamName(%arg)   %arg
#def1arg CodeNormalizeProperty(%arg)        $Select(%arg?1.A.AN:%arg,1:""""_%arg_"""")
#define zNormalizeClassName(%arg)           $zstrip(%arg, "*P")
