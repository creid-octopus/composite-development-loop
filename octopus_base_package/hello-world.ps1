# Sample script - works with input Octopus Deploy variable and displays output

# Get the value of the Octopus variable
$scriptMessage = $OctopusParameters["Project.ScriptMessage"]

# Display the value of the variable in the task log UI
Write-Highlight "The value of Project.ScriptMessage is: $scriptMessage"