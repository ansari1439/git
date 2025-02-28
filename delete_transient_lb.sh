#!/bin/bash

# Prompt user to enter the names to match
echo "Enter the names to match (use quotes for names with spaces, e.g., 'test 2' 'brand new')"
read -r names_input  # Read the entire input as a single string

# Split names correctly, handling quotes
IFS=$'\n' read -rd '' -a names <<< "$(echo $names_input | xargs -n1 echo | sed 's/^"//;s/"$//')"

# Run atlascli to set up the environment and execute the node search
output=$(atlascli --adv --cmd "node search --hidden=only pinboard --num 1000")
if [ $? -ne 0 ]; then
    echo "Error running atlascli. Exiting."
    exit 1
fi

# Print the output of the node search (for debugging)
#echo "Node search output:"
#echo "$output"

# Clear or create the commands file
> commands.sh

# Initialize an associative array to track processed IDs
declare -A processed_ids

# Loop through the input names
for name in "${names[@]}"; do
    echo "Searching for nodes matching '$name'..."
    # Extract the IDs and names from the output and search for matches
    matching_nodes=$(echo "$output" | grep -i "$name" | awk '{id=$1; $1=""; print id, $0}')

    # Check if any nodes match the input names
    if [ -n "$matching_nodes" ]; then
        echo "Matching nodes found for '$name':"
        
        # Loop through matching nodes and print full ID and name
        while read -r line; do
            echo "$line"
        done <<< "$matching_nodes"
        
        # Extract the IDs for deletion using a regular expression for valid UUID format
        ids=$(echo "$matching_nodes" | grep -oP '\b([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})\b')

        # Loop through each ID and add to the commands file if it hasn't been processed yet
        for id in $ids; do
            if [[ -z "${processed_ids[$id]}" ]]; then
                # Add the delete command for each node to the commands file
                echo "node delete $id" >> commands.sh
                echo "Added delete for node with ID $id"
                # Mark the node as processed
                processed_ids[$id]=1
            fi
        done
    else
        echo "No nodes found for '$name'."
    fi
done

# Add the commit command once at the end
echo "commit --msg 'deleting transient LB created way VCS'" >> commands.sh
echo "Added commit message to the end of the commands."

# Make the commands file executable
chmod +x commands.sh

# Ask user for confirmation before running the commands file
echo "Do you want to proceed and execute the delete commands? (YES/NO)"
read confirm_run

if [ "$confirm_run" == "YES" ]; then
    # Run the commands file using atlascli and capture the output
    echo "Executing all delete and commit commands..."
    atlascli_output=$(atlascli --adv --file "commands.sh")

    # Check if the atlascli command was successful
    if [ $? -ne 0 ]; then
        echo "Error running the commands file. Please check the commands.sh file."
        echo "AtlasCLI output: $atlascli_output"
        exit 1
    fi

    # Output the result of the atlascli execution
    echo "AtlasCLI output: $atlascli_output"
    echo "All deletions and commits executed successfully."
else
    echo "Operation cancelled. No actions were taken."
fi

# Remove the commands.sh file after execution
rm -f commands.sh
#echo "commands.sh file removed."

# Exit the script
exit 0
