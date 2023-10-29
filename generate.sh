#!/bin/bash

# Developer: Syed Ali Bilgrami
# repo link: https://github.com/bilgrami/soundraw
# Last modified Date: 2023-10-28
# Purpose: Generate AI based music using Soundraw API.
# Usage: ./generate.sh <param_file_name> <num_batches> <length>

# Note: This script requires the following environment variables to be set in .secret file:
# export AUTH_TOKEN=<add auth token from soundraw api here>
# export URL=https://soundraw.io/api/v2/musics/compose

trim() {
    echo "$1" | awk '{$1=$1};1'
}

print_banner() {
    echo -e "\e[1;32m " # enable formatting 
    echo -e "============================================================== "
    echo -e "       AI Music Generator via Soundraw API                     "
    echo -e "                                                                       "
    echo -e "  Author: Syed Bilgrami                                        "
    echo -e "  Repo link: https://github.com/bilgrami/soundraw              "
    echo -e "  Last modified Date: 2023-10-28                               "
    echo -e "  Purpose: Generate AI based music using Soundraw API.         "
    echo -e "=============================================================="
}

print_usage() {
    echo "Usage: $0 <param_file_name> <num_batches> <length>"
    echo "Example: $0 soundraw_params.csv 2 300"
}

print_banner

# Check if three arguments are provided or no argument is provided, print usage if not
if [ $# -ne 3 ] && [ $# -ne 0 ]; then
    print_usage
    exit 1
fi

export param_file_name=${1:-soundraw_params.csv}
export num_batches=${2:-2}
export length=${3:-300}

# no changes beyond this point

export max_retries=3
export max_download_timeout=600
export retry_wait=5 # seconds

echo -e "Params:"
echo "      param_file_name: $param_file_name"
echo "      num_batches: $num_batches"
echo "      length: $length"
echo -e "=============================================================="
echo -e "\e[0m" # disable formatting 

# Load environment variables
source .secret
set -e
set -o pipefail

# Create a subfolder with today's date
today=$(date +%Y-%m-%d)
today_ts=$(date +%Y-%m-%d-%H-%M-%S)

mkdir -p "output/$today/music"
mkdir -p "output/$today/response"
mkdir -p "output/$today/temp"

# Extract the base name of the parameter file
param_file_base_name=$(basename "$param_file_name")
error_params_dir="output/$today/errors"
mkdir -p "$error_params_dir"
error_params_file="$error_params_dir/$today_ts-$param_file_base_name-errors.csv"
echo "Any Param containing errors will be saved at => $error_params_file"

line_number=1
tail -n +2 "$param_file_name" | while IFS=, read -r moods genres themes tempo tempo_2 energy_levels; do
    line_number=$((line_number + 1))

    for i in $(seq 1 $num_batches)
    do
        batch_id="batch-$i"
        # echo "moods:$moods, genres:$genres, themes:$themes, tempo:$tempo, tempo_2:$tempo_2, energy_levels:$energy_levels, length:300"
        output_file_name=$(echo "$today_ts-$genres-$moods-$themes-$length" | sed 's/&//g; s/ /_/g')
        output_file_name="${output_file_name}-${batch_id}-$(shuf -i 1-10000 -n 1).m4a"
        response_output_file_name=$(echo "${output_file_name}.json" | sed 's/\.m4a//')
        temp_response_json_full_path="output/$today/temp/$response_output_file_name"
        response_json_full_path="output/$today/response/$response_output_file_name"

        echo "-----------------------------------------------------"
        echo "Param Line $line_number) - batch $i - Music Params: "
        echo "  Moods: $moods"
        echo "  Genres: $genres"
        echo "  Themes: $themes"
        echo "  Tempo: $tempo"
        echo "  Energy Levels: $energy_levels"
        echo "  Length: $length"

        echo "  Music file name => $output_file_name"

        post_payload='{
            "genres": "'"$(trim "$genres")"'",
            "moods": "'"$(trim "$moods")"'",
            "themes": "'"$(trim "$themes")"'",
            "length": "'"$(trim "$length")"'"
        }'

        response=$(curl -s $URL \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $AUTH_TOKEN" \
            -X POST \
            -d "$post_payload")

        echo "response => $response"
        echo "{\"param\": " > $temp_response_json_full_path
        echo "$post_payload" | jq . >> $temp_response_json_full_path
        echo ",\"result\" : " >> $temp_response_json_full_path
        echo "$response" | jq . >> $temp_response_json_full_path
        echo "}" >> $temp_response_json_full_path
        cat $temp_response_json_full_path | jq . > $response_json_full_path
        rm -f $temp_response_json_full_path
       
        m4a_url=$(echo $response | jq -r '.m4a_url')
        if [[ -z "$m4a_url" ]] || [[ "$m4a_url" == "null" ]]; then
            echo "Error: m4a_url is empty! Please ensure params are valid on line $line_number in your param file: $param_file_name"

            if [ ! -f "$error_params_file" ]; then
                echo "moods,genres,themes,tempo,tempo_2,energy_levels,length" > "$error_params_file"
            fi

            # append the parameters to the $error_params_file only when the batch number is 1.
            if [ "$i" -eq 1 ] ; then            
                echo "$moods,$genres,$themes,$tempo,$tempo_2,$(trim $energy_levels),$length" >> "$error_params_file"
            fi

            continue
        fi

        attempt=1

        while :; do
            echo "Attempt $attempt/$max_retries:"
            if curl -C - --max-time $max_download_timeout -o "output/$today/music/$output_file_name" "$m4a_url"; then
                echo "Download completed successfully."
                break
            else
                if [ $attempt -ge $max_retries ]; then
                    echo "Maximum number of attempts reached. To resume the download, run the script again."
                    break
                fi
                attempt=$((attempt + 1))
                echo "Waiting $retry_wait seconds before retry..."
                sleep 5
            fi
        done


    done
done

if [ -f "$error_params_file" ]; then
    echo -e "\e[31m " # enable formatting 
    echo -e "There were errors. Please check params containing errors at '$error_params_file'"
    echo -e "\e[0m" # disable formatting 
fi

echo -e "\e[1;32m " # enable formatting 
echo -e "============================================================== "
echo -e "                    Thank You                                  "
echo -e "                                                               "
echo -e "  We appreciate your contribution and support.                 "
echo -e "  Looking forward to achieving more great things together!     "
echo -e "============================================================== "
echo -e "\e[0m" # disable formatting 
