#!/usr/bin/env bash
# Sample script - works with input Octopus Deploy variable and displays output

# Get the value of the Octopus variable
scriptMessage=$(get_octopusvariable "Project.ScriptMessage")

# Display the value of the variable in the task log UI
write_highlight "The value of Project.ScriptMessage is: $scriptMessage"
