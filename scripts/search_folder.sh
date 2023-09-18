#!/bin/bash

# Function to recursively search for a folder name
search_folder() {
    local search_dir="$1"
    echo "Searching for maps"

    for item in "$search_dir"/*; do
        # Check if the given directory exists
        if [ -d "$search_dir" ]; then                
            # Check if there is a "maps" folder within the "mods" directory
            if [ -d "$item/mods" ]; then
                # echo "Searching in: $item/mods" <-- for debugging purposes 
                for mod_folder in "$item/mods"/*; do
                    if [ -d "$mod_folder/media/maps" ]; then
                
                        # Copy maps to map folder
                        cp -r "$mod_folder/media/maps"/* "${HOMEDIR}/pz-dedicated/media/maps"

                        # Adds map names to a semicolon separated list and outputs it.
                        map_list=""
                        for dir in "$mod_folder/media/maps"/*/; do
                            echo "Found maps: $dir"
                            if [ -d "$dir" ]; then
                                dir_name=$(basename "$dir")
                                map_list+="$dir_name;"     
                            fi
                        done
                            echo -n "$map_list" >> "${HOMEDIR}/maps.txt"
                    fi
                done
            fi
        fi
    done
}

parent_folder="$1"

if [ ! -d "$parent_folder" ]; then
    exit 1
fi

# Call the search_folder function with the provided arguments
search_folder "$parent_folder"