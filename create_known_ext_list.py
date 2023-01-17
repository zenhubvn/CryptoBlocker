import json
from datetime import datetime

def create_json_file():
    with open("${{ github.workspace }}/list.txt", "r") as file:
        knownExtensions = [line.strip() for line in file]
    jsonTemp = {
        "api": {
            "version": 1,
            "format": "json",
            "file_group_count": len(knownExtensions)
        },
        "lastUpdated": datetime.utcnow().isoformat() + "Z",
        "filters": 
            knownExtensions
    }
    with open("${{ github.workspace }}/KnownExtensions.txt", "w") as outFile:
        json.dump(jsonTemp, outFile)


create_json_file()
