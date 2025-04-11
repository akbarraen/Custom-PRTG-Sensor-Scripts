import os
import re

# Directories to skip when scanning the repository.
SKIP_DIRS = {".git", ".github", "__pycache__", "node_modules"}

def get_synopsis(file_path):
    """
    Reads a PowerShell (.ps1) file and returns the string from the .SYNOPSIS section.
    It looks on the same line as .SYNOPSIS or, if empty, the next non-blank line.
    """
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
            for i, line in enumerate(lines):
                if '.SYNOPSIS' in line:
                    # Try to extract description from same line if present.
                    match = re.search(r'\.SYNOPSIS\s*[:-]?\s*(.*)', line, re.IGNORECASE)
                    if match:
                        description = match.group(1).strip()
                        if description:
                            return description
                        # Otherwise, look in the subsequent lines for non-blank text.
                        for j in range(i+1, len(lines)):
                            next_line = lines[j].strip().lstrip('#').strip()
                            if next_line:
                                return next_line
                    break
    except Exception as e:
        return ""
    return ""

def generate_sensor_list():
    sensor_list = "Sensor List:\n"
    # Iterate through each environment folder at the repository root.
    for env in sorted(os.listdir(".")):
        if os.path.isdir(env) and env not in SKIP_DIRS:
            sensor_list += f"- **[{env}:](./{env})**\n"
            env_path = os.path.join(".", env)
            # List any .ps1 files directly in the environment folder.
            for file in sorted(os.listdir(env_path)):
                f_path = os.path.join(env_path, file)
                if os.path.isfile(f_path) and file.lower().endswith(".ps1"):
                    synopsis = get_synopsis(f_path)
                    sensor_list += f"  - *{file}*"
                    if synopsis:
                        sensor_list += f" - {synopsis}"
                    sensor_list += "\n"
            # Now, list sensor files in subdirectories
            for sub in sorted(os.listdir(env_path)):
                sub_path = os.path.join(env_path, sub)
                if os.path.isdir(sub_path):
                    sensor_list += f"  - **[{sub}](./{env}/{sub})**\n"
                    for file in sorted(os.listdir(sub_path)):
                        f_sub_path = os.path.join(sub_path, file)
                        if os.path.isfile(f_sub_path) and file.lower().endswith(".ps1"):
                            synopsis = get_synopsis(f_sub_path)
                            sensor_list += f"    - *{file}*"
                            if synopsis:
                                sensor_list += f" - {synopsis}"
                            sensor_list += "\n"
    return sensor_list

def generate_repository_structure():
    structure = "```\nCustom-PRTG-Sensor-Scripts/\n"
    # List only directories (environments) at the repository root, excluding SKIP_DIRS.
    for item in sorted(os.listdir(".")):
        if os.path.isdir(item) and item not in SKIP_DIRS:
            structure += f"├── {item}/\n"
            env_path = os.path.join(".", item)
            # List .ps1 files directly in the environment folder.
            for f in sorted(os.listdir(env_path)):
                f_path = os.path.join(env_path, f)
                if os.path.isfile(f_path) and f.lower().endswith(".ps1"):
                    structure += f"│   ├── {f}\n"
            # List subdirectories in the environment folder.
            for sub in sorted(os.listdir(env_path)):
                sub_path = os.path.join(env_path, sub)
                if os.path.isdir(sub_path):
                    structure += f"│   ├── {sub}/\n"
                    for file in sorted(os.listdir(sub_path)):
                        f_file = os.path.join(sub_path, file)
                        if os.path.isfile(f_file) and file.lower().endswith(".ps1"):
                            structure += f"│   │   ├── {file}\n"
                    if "README.md" in os.listdir(sub_path):
                        structure += f"│   │   └── README.md\n"
            if "README.md" in os.listdir(env_path):
                structure += f"│   ├── README.md\n"
    structure += "```\n"
    return structure

def update_readme():
    import re
    readme_path = "README.md"
    with open(readme_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Generate the updated sections.
    new_sensor_list = generate_sensor_list()
    new_repo_structure = generate_repository_structure()

    # Define regex patterns for the sensor list and repository structure markers.
    sensor_pattern = r"(<!-- SENSOR LIST START -->)(.*?)(<!-- SENSOR LIST END -->)"
    repo_pattern = r"(<!-- REPO STRUCTURE START -->)(.*?)(<!-- REPO STRUCTURE END -->)"

    sensor_replacement = f"<!-- SENSOR LIST START -->\n{new_sensor_list}\n<!-- SENSOR LIST END -->"
    repo_replacement = f"<!-- REPO STRUCTURE START -->\n{new_repo_structure}\n<!-- REPO STRUCTURE END -->"

    new_content = re.sub(sensor_pattern, sensor_replacement, content, flags=re.DOTALL)
    new_content = re.sub(repo_pattern, repo_replacement, new_content, flags=re.DOTALL)

    with open(readme_path, "w", encoding="utf-8") as f:
        f.write(new_content)

if __name__ == "__main__":
    update_readme()
