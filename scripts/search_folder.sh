#!/bin/bash

# Function to recursively search for a folder name
search_folder() {
    local search_dir="$1"
    counter=1

    for item in "$search_dir"/*; do

        echo "Searching for maps: ($counter/$(ls -1 "$search_dir" | wc -l))"

        # Check if the given directory exists
        if [ -d "$search_dir" ]; then                
            # Check if there is a "maps" folder within the "mods" directory
            if [ -d "$item/mods" ]; then
                for mod_folder in "$item/mods"/*; do
                    if [ -d "$mod_folder/media/maps" ]; then
                
                        # Copy maps to map folder
                        source_dirs=("$mod_folder/media/maps"/*)
                        map_dir=("${HOMEDIR}/pz-dedicated/media/maps")

                        for source_dir in "${source_dirs[@]}"; do
                            dir_name=$(basename "$source_dir")
                            if [ ! -d "$map_dir/$dir_name" ]; then
                                echo "Found map(s). Copying..."
                                cp -r "$mod_folder/media/maps"/* "${HOMEDIR}/pz-dedicated/media/maps"
                                echo "Successfully copied!"
                            fi
                        done

                        # Adds map names to a semicolon separated list and outputs it.
                        map_list=""
                        for dir in "$mod_folder/media/maps"/*/; do
                            if [ -d "$dir" ]; then
                                dir_name=$(basename "$dir")
                                map_list+="$dir_name;"     
                            fi
                        done
                        # Exports to .txt file to add to .ini file in entry.sh
                            echo -n "$map_list" >> "${HOMEDIR}/maps.txt"
                    fi
                done
            fi
        fi
        ((counter++))
    done
}

parent_folder="$1"

if [ ! -d "$parent_folder" ]; then
    exit 1
fi

# Call the search_folder function with the provided arguments
search_folder "$parent_folder"