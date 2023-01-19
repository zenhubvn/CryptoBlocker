from collections import defaultdict
import sys

def check_duplicated_extensions():
    with open("list.txt", "r", encoding="utf8") as file:
        knownExtensions = [line.strip() for line in file]
    
    indeces = defaultdict(list)

    for i, w in enumerate(knownExtensions):
        indeces[w].append(i)

    # When reading the line numbers make sure to add +1 as we start the count from zero
    for extension_name, line_number in indeces.items():
        if len(line_number) >= 1:
            # Create a error and output the duplicates, fix them and than run again
            print(extension_name, line_number, file=sys.stderr)
            sys.exit(59)
        else:
            # Write something to trigger workflow create known extensions txt file
            print("Calling other workflow....", file=sys.stderr)
            sys.exit(0)


check_duplicated_extensions()
