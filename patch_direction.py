import sys

def patch_file():
    with open("lib/services/direction_service.dart", "r") as f:
        content = f.read()

    old_code = """        entry.value.sort(
          (a, b) =>
              (a['stopSequence'] as int).compareTo(b['stopSequence'] as int),
        );
        for (int j = 0; j < entry.value.length - 1; j++) {"""
        
    new_code = """        entry.value.sort(
          (a, b) =>
              (a['stopSequence'] as int).compareTo(b['stopSequence'] as int),
        );
        for (int j = 0; j < entry.value.length; j++) {
          entry.value[j]['lineName'] ??= defaultLineName;
        }
        for (int j = 0; j < entry.value.length - 1; j++) {"""
    
    if old_code in content:
        content = content.replace(old_code, new_code)
        with open("lib/services/direction_service.dart", "w") as f:
            f.write(content)
        print("Patched direction_service.dart successfully.")
    else:
        print("Could not find the target code in import sys

def patch_file():
   file()
