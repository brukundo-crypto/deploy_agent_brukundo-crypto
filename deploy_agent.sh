#!/usr/bin/env bash
# deploy_agent.sh - deploys, runs and archives the Student Attendance Tracker

check_dependencies() {
    echo "Checking required tools..."

    if ! command -v python3 > /dev/null 2>&1; then
        echo "ERROR: python3 is not installed. Cannot continue."
        exit 1
    fi
    echo "  Found: $(python3 --version)"

    if ! command -v zip > /dev/null 2>&1; then
        echo "ERROR: zip is not installed. Cannot continue."
        exit 1
    fi
    echo "  Found: zip"

    echo "All required tools are available."
}

deploy_project() {
    check_dependencies

    read -p "Enter a project name: " project_name

    if [ -z "$project_name" ]; then
        echo "ERROR: Project name cannot be empty."
        exit 1
    fi

    project_dir="attendance_tracker_${project_name}"

    if [ -d "$project_dir" ]; then
        echo "WARNING: '$project_dir' already exists."
        read -p "Overwrite it? [y/N]: " answer
        if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
            rm -rf "$project_dir"
            echo "Removed the old '$project_dir'."
        else
            echo "Aborted. Nothing was changed."
            exit 1
        fi
    fi

    echo "Creating project structure..."
    mkdir -p "$project_dir/Helpers"
    mkdir -p "$project_dir/reports"
    echo "  Created: $project_dir/"
    echo "  Created: $project_dir/Helpers/"
    echo "  Created: $project_dir/reports/"
}

show_menu() {
    echo ""
    echo "====================================="
    echo "  Attendance Tracker Deploy Agent"
    echo "====================================="
    echo "  1) Deploy a new project"
    echo "  2) Run an existing project"
    echo "  3) Archive the log files"
    echo "  4) Exit"
    echo "====================================="
}

show_menu
read -p "Choose an option [1-4]: " choice

case "$choice" in
    1)
        deploy_project
        ;;
    2)
        echo "You chose: Run"
        ;;
    3)
        echo "You chose: Archive"
        ;;
    4)
        echo "Goodbye."
        exit 0
        ;;
    *)
        echo "Invalid option. Please choose 1-4."
        exit 1
        ;;
esac
