#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input_folder> <output_dart_file>"
    exit 1
fi

input_folder=$1
output_dart_file=$2

# Function to convert snake_case or kebab-case to camelCase
to_camel_case() {
    echo "$1" | awk -F '[-_]' '{for (i=1; i<=NF; i++) {if (i == 1) {printf "%s", $i} else {printf "%s%s", toupper(substr($i,1,1)), substr($i,2)}}}'
}

# Start the Dart class definition with suppression of all warnings
echo "// ignore_for_file: all" > $output_dart_file
echo "" >> $output_dart_file
echo "class StringifyAssets {" >> $output_dart_file

# Loop through all YAML files in the input folder
for file in "$input_folder"/*.yaml; do
    # Extract the filename without the extension
    filename=$(basename -- "$file")
    variable_name="${filename%.*}"
    camel_case_variable=$(to_camel_case "$variable_name")

    # Read the YAML file content, escape newlines, double quotes, and $ character
    yaml_content=$(awk '{gsub(/"/, "\\\""); gsub(/\$/, "\\$"); printf "%s\\n", $0}' "$file")

    # Append the YAML content as a Dart string variable to the output file
    echo "  static const String $camel_case_variable = \"$yaml_content\";" >> $output_dart_file
done

# End the Dart class definition
echo "}" >> $output_dart_file

echo "Dart class with YAML strings has been generated at $output_dart_file."
