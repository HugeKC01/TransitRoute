import os
import glob
import re

def fix_svg(filepath):
    with open(filepath, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # 1. Inline CSS from <style> blocks
    style_match = re.search(r'<style[^>]*>(.*?)</style>', content, re.DOTALL | re.IGNORECASE)
    if style_match:
        style_text = style_match.group(1)
        # Find all rules inside <style>
        # Typical SVG style blocks: .cls-1 { fill: #fff; } or .a, .b { fill: none; }
        rules = re.findall(r'([^\{]+)\{([^\}]+)\}', style_text)
        
        class_styles = {}
        for sel, props in rules:
            selectors = [s.strip().replace('.', '') for s in sel.split(',')]
            props = props.strip()
            # replace newlines with space
            props = re.sub(r'\s+', ' ', props)
            for s in selectors:
                if s not in class_styles:
                    class_styles[s] = props
                else:
                    class_styles[s] += ";" + props

        new_content = content
        # For each class, replace `class="cls"` with `style="props"`
        for cname, cprops in class_styles.items():
            pattern = r'class=[\'"]' + re.escape(cname) + r'[\'"]'
            
            def replace_class(match):
                return f'style="{cprops}"'
            
            new_content = re.sub(pattern, replace_class, new_content)

        # Remove the processed <style> block
        new_content = re.sub(r'<style[^>]*>.*?</style>', '', new_content, flags=re.DOTALL | re.IGNORECASE)
        # Remove empty <defs></defs>
        new_content = re.sub(r'<defs>\s*</defs>', '', new_content, flags=re.IGNORECASE)

        with open(filepath, 'w', encoding='utf-8') as file:
            file.write(new_content)
        print(f"Fixed classes in {filepath}")

    # 2. Fix overriding `color:` that flutter_svg propagates incorrectly as black.
    # Flutter SVG sometimes applies `color: #000;` as the fill color if we have a `style="fill: #xyz;"`.
    # Let's remove `color:` from style attributes just to be safe if a solid fill exists.
    with open(filepath, 'r', encoding='utf-8') as file:
        new_content = file.read()
    
    def strip_color(match):
        style_str = match.group(1)
        style_str = re.sub(r'color\s*:\s*#[0-9a-fA-F]+;?\s*', '', style_str)
        return f'style="{style_str}"'
    
    new_content = re.sub(r'style="([^"]+)"', strip_color, new_content)
    
    # 3. Handle `fill: currentColor;` if present and replacing with an explicit color
    # This might not be needed, but good to check.

    with open(filepath, 'w', encoding='utf-8') as file:
        file.write(new_content)

if __name__ == '__main__':
    d = 'assets/icons/'
    for f in glob.glob(d + '*.svg'):
        fix_svg(f)
    print("Done")
