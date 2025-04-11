import os

# Directories we want to skip (hidden or not relevant)
SKIP_DIRS = {".git", ".github", "__pycache__", "node_modules"}

def generate_sensor_list():
    sensor_list = "Sensor List:\n"
    # Loop over environment folders at the repository root
    for env in sorted(os.listdir(".")):
        if os.path.isdir(env) and env not in SKIP_DIRS:
            sensor_list += f"- **[{env}:](./{env})**\n"
            env_path = os.path.join(".", env)
            # List any .ps1 files directly in the environment folder
            for file in sorted(os.listdir(env_path)):
                f_path = os.path.join(env_path, file)
                if os.path.isfile(f_path) and file.lower().endswith(".ps1"):
                    sensor_list += f"  - *{file}*\n"
            # Now, list the subfolders inside the environment
            for sub in sorted(os.listdir(env_path)):
                sub_path = os.path.join(env_path, sub)
                if os.path.isdir(sub_path):
                    sensor_list += f"  - **[{sub}](./{env}/{sub})**\n"
                    # List .ps1 files in the subfolder
                    for file in sorted(os.listdir(sub_path)):
                        f_sub_path = os.path.join(sub_path, file)
                        if os.path.isfile(f_sub_path) and file.lower().endswith(".ps1"):
                            sensor_list += f"    - *{file}*\n"
    return sensor_list

def generate_repository_structure():
    structure = "```\nCustom-PRTG-Sensor-Scripts/\n"
    # List only directories in the repository's root excluding skip directories.
    for item in sorted(os.listdir(".")):
        if os.path.isdir(item) and item not in SKIP_DIRS:
            structure += f"├── {item}/\n"
            env_path = os.path.join(".", item)
            # List any files (like .ps1) in the environment folder
            for f in sorted(os.listdir(env_path)):
                f_path = os.path.join(env_path, f)
                if os.path.isfile(f_path) and f.lower().endswith(".ps1"):
                    structure += f"│   ├── {f}\n"
            # Then list subdirectories inside the environment folder
            for sub in sorted(os.listdir(env_path)):
                sub_path = os.path.join(env_path, sub)
                if os.path.isdir(sub_path):
                    structure += f"│   ├── {sub}/\n"
                    for file in sorted(os.listdir(sub_path)):
                        f_file = os.path.join(sub_path, file)
                        if os.path.isfile(f_file) and file.lower().endswith(".ps1"):
                            structure += f"│   │   ├── {file}\n"
                    # Optionally list README.md if present
                    if "README.md" in os.listdir(sub_path):
                        structure += f"│   │   └── README.md\n"
            # Also add README.md from the environment folder if it exists
            if "README.md" in os.listdir(env_path):
                structure += f"│   ├── README.md\n"
    structure += "```\n"
    return structure

def update_readme():
    import re
    readme_path = "README.md"
    with open(readme_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Generate new sections
    new_sensor_list = generate_sensor_list()
    new_repo_structure = generate_repository_structure()

    # Use regex to replace text between our markers
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
