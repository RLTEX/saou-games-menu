Option Explicit

Dim shell
Dim args
Dim command
Dim exitCode
Dim index

Set args = WScript.Arguments

If args.Count < 1 Then
    WScript.Quit 64
End If

command = QuoteArgument(args(0))

For index = 1 To args.Count - 1
    command = command & " " & QuoteArgument(args(index))
Next

Set shell = CreateObject("WScript.Shell")

On Error Resume Next
exitCode = shell.Run(command, 0, True)

If Err.Number <> 0 Then
    WScript.Quit 1
End If

On Error GoTo 0
WScript.Quit exitCode

Function QuoteArgument(value)
    Dim text

    text = CStr(value)

    If InStr(text, """") > 0 Or InStr(text, vbCr) > 0 Or InStr(text, vbLf) > 0 Then
        WScript.Quit 65
    End If

    QuoteArgument = """" & text & """"
End Function
