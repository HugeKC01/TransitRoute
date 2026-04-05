import glob
import re

d = 'assets/icons/'
for f in glob.glob(d + '*.svg'):
    with open(f, 'r') as file:
        content = file.read()
    
    # Replace double semicolons
    content = content.replace(';;', ';')
    
    # Try converting simple style="fill: #xxx; stroke..." to individual attributes
    def style_to_attrs(match):
        style_str = match.group(1)
        attrs = []
        for prop in style_str.split(';'):
            prop = prop.strip()
            if not prop: continue
            if ':' in prop:
                key, val = prop.split(':', 1)
                attrs.append(f'{key.strip()}="{val.strip()}"')
        return " ".join(attrs)

    new_content = re.sub(r'style="([^"]*)"', style_to_attrs, content)
    
    if new_content != content:
        with open(f, 'w') as file:
            file.write(new_content)
        print(f"Fixed attributes in {f}")

print("Done")
