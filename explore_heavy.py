import re

def insert_yields(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Simple regex to find for loops over lines and add a yield
    # Find: for (int i = 1; i < lines.length; i++) {
    content = re.sub(
        r'(for\s*\([^\{]+\)\s*\{)(.*?)(})',
        lambda m: m.group(1) + m.group(2) + m.group(3),
        content,
        flags=re.DOTALL
    )

