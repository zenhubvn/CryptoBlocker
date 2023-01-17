import json
from datetime import datetime

def create_json_file():
    with open("list.txt", "r", encoding="utf8") as file:
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
    with open("KnownExtensions.txt", "w", encoding="utf8") as outFile:
        outFile.write(str(jsonTemp))


create_json_file()
