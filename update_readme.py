import os
import re

# Skip directories that are not environments
SKIP_DIRS = {".github", "__pycache__", "node_modules"}

def generate_sensor_list():
    sensor_list = "Sensor List:\n"
    # Look for environment folders at the root
    for env in sorted(os.listdir(".")):
        if os.path.isdir(env) and env not in SKIP_DIRS:
            # Add link with environment name
            sensor_list += f"- **[{env}:](./{env})**\n"
            # Walk inside the environment folder to find subfolders with .ps1 files
            env_path = os.path.join(".", env)
            subfolders = {}
            for root, dirs, files in os.walk(env_path):
                for file in sorted(files):
                    if file.lower().endswith(".ps1"):
                        rel_dir = os.path.relpath(root, env_path)
                        if rel_dir == ".":
                            rel_dir = env  # if the script is directly under env folder
                        subfolders.setdefault(rel_dir, []).append(file)
            # For each subfolder, list its sensor script(s)
            for subfolder, scripts in sorted(subfolders.items()):
                sensor_list += f"  - **[{subfolder}](./{env}/{subfolder.replace(env, '').lstrip(os.sep)})**\n"
                for script in sorted(scripts):
                    sensor_list += f"    - *{script}*\n"
    return sensor_list

def generate_repository_structure():
    structure = "```\nCustom-PRTG-Sensor-Scripts/\n"
    # Look for environment folders at root
    for env in sorted(os.listdir(".")):
        if os.path.isdir(env) and env not in SKIP_DIRS:
            structure += f"├── {env}/\n"
            env_path = os.path.join(".", env)
            # List only directories (subfolders) inside each environment
            for sub in sorted(os.listdir(env_path)):
                sub_path = os.path.join(env_path, sub)
                if os.path.isdir(sub_path):
                    structure += f"│   ├── {sub}/\n"
                    # List .ps1 files in the subfolder
                    for file in sorted(os.listdir(sub_path)):
                        if file.lower().endswith(".ps1"):
                            structure += f"│   │   ├── {file}\n"
                    # Also check if there is a README in the subfolder
                    if "README.md" in os.listdir(sub_path):
                        structure += f"│   │   └── README.md\n"
    structure += "```\n"
    return structure

def update_readme():
    readme_path = "README.md"
    with open(readme_path, "r", encoding="utf-8") as f:
        content = f.read()

    # Generate new sections
    new_sensor_list = generate_sensor_list()
    new_repo_structure = generate_repository_structure()

    # Define regex patterns to match our markers:
    sensor_pattern = re.compile(r"(<!-- SENSOR LIST START -->)(.*?)(<!-- SENSOR LIST END -->)", re.DOTALL)
    repo_pattern = re.compile(r"(<!-- REPO STRUCTURE START -->)(.*?)(<!-- REPO STRUCTURE END -->)", re.DOTALL)

    # Prepare replacement text including markers
    sensor_replacement = f"<!-- SENSOR LIST START -->\n{new_sensor_list}\n<!-- SENSOR LIST END -->"
    repo_replacement = f"<!-- REPO STRUCTURE START -->\n{new_repo_structure}\n<!-- REPO STRUCTURE END -->"

    content = sensor_pattern.sub(sensor_replacement, content)
    content = repo_pattern.sub(repo_replacement, content)

    with open(readme_path, "w", encoding="utf-8") as f:
        f.write(content)

if __name__ == "__main__":
    update_readme()
