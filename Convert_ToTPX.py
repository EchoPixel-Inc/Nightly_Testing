import os
import re
import sys

def process_html_data_file(filepath):
    """Processes a single .html.data file according to the specific rules."""
    try:
        # Read the original file
        with open(filepath, 'r', encoding='utf-8') as file:
            lines = file.readlines()
        
        modified_lines = []
        
        # Matches 'TRX_' ONLY IF it is NOT followed by a sequence of characters
        # ending in a common image/video extension.
        media_avoidance_pattern = r'TRX_(?![^"\'\s<>]*\.(?:png|jpg|jpeg|gif|bmp|mkv|mp4|avi|mov|wmv)\b)'

        for line in lines:
            # 1. Remove the entire row that contains the word "Success"
            if "Success" in line:
                continue
            
            # 2. Change text matching "TRX_" to "TPX_", ignoring media file paths
            new_line = re.sub(media_avoidance_pattern, 'TPX_', line)
            
            modified_lines.append(new_line)

        # 3. Save the file with its original name (overwrite)
        with open(filepath, 'w', encoding='utf-8') as file:
            file.writelines(modified_lines)

        print(f"Processed: '{filepath}'")

    except Exception as e:
        print(f"Error processing '{filepath}': {e}")

def process_directory(directory_path):
    """Recursively searches for .html.data files in the given directory."""
    if not os.path.isdir(directory_path):
        print(f"Error: The directory '{directory_path}' does not exist or is not a valid folder.")
        return

    print(f"Scanning directory: {directory_path}...\n")
    found_files = 0

    # os.walk recursively visits the root folder and all subfolders
    for root, _, files in os.walk(directory_path):
        for file in files:
            if file.endswith('.html.data'):
                found_files += 1
                full_filepath = os.path.join(root, file)
                process_html_data_file(full_filepath)
                
    if found_files == 0:
        print("No '.html.data' files were found in the specified directory.")
    else:
        print(f"\nComplete. Processed {found_files} file(s).")

if __name__ == "__main__":
    # Ensure a folder argument is provided when run from the command line
    if len(sys.argv) > 1:
        target_directory = sys.argv[1]
        process_directory(target_directory)
    else:
        print('Usage: python script.py "C:\\Path\\To\\Your\\Directory"')