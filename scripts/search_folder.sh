#!/bin/bash

# Function to recursively search for a folder name
search_folder() {
    local search_dir="$1"
    local target_folder_name="$2"
    
    # Check if the given directory exists
    if [ -d "$search_dir" ]; then
        # Check if the "mods" subfolder exists within the directory
        if [ -d "$search_dir/mods" ]; then
            # Check if the target folder exists within the "mods" subfolder
            if [ -d "$search_dir/mods/$target_folder_name" ]; then
		        cp -r "$search_dir/mods/$target_folder_name/media/maps"/* "${HOMEDIR}/pz-dedicated/media/maps"
                directory_list=""
                for dir in "$search_dir/mods/$target_folder_name/media/maps"/*/; do
                    if [ -d "$dir" ]; then
                        dir_name=$(basename "$dir")
                        if [ -z "$directory_list" ]; then
                            directory_list="$dir_name;"
                        else
                            directory_list="$directory_list;$dir_name"
                        fi
                    fi
                done
                echo "$directory_list"
            fi
        fi

        # Recursively search in subdirectories
        for item in "$search_dir"/*; do
            if [ -d "$item" ]; then
                
                search_folder "$item" "$target_folder_name"
            fi
        done
    fi
}

# Usage: Provide the parent folder and the target folder name as arguments
if [ "$#" -ne 2 ]; then
    exit 1
fi

parent_folder="$1"
target_folder_name="$2"

if [ ! -d "$parent_folder" ]; then
    exit 1
fi

# Call the search_folder function with the provided arguments
search_folder "$parent_folder" "$target_folder_name"