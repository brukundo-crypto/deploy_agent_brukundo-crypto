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

build_roster() {
    echo ""
    echo "How should the student roster be built?"
    echo "  A) Copy students from the sample roster"
    echo "  B) Generate a fresh roster (all counts start at 0)"
    read -p "Choose [A/B]: " roster_choice

    case "$roster_choice" in
        a|A)
            read -p "How many students to copy? (1-10): " student_count
            if ! [[ "$student_count" =~ ^[0-9]+$ ]]; then
                echo "ERROR: That is not a number."
                exit 1
            fi
            if [ "$student_count" -lt 1 ] || [ "$student_count" -gt 10 ]; then
                echo "ERROR: Please choose between 1 and 10."
                exit 1
            fi
            head -n $((student_count + 1)) templates/assets.csv > "$project_dir/Helpers/assets.csv"
            total_sessions=5
            echo "  Copied $student_count students from the sample roster."
            ;;
        b|B)
            read -p "How many students to generate? (1-10): " student_count
            if ! [[ "$student_count" =~ ^[0-9]+$ ]]; then
                echo "ERROR: That is not a number."
                exit 1
            fi
            if [ "$student_count" -lt 1 ] || [ "$student_count" -gt 10 ]; then
                echo "ERROR: Please choose between 1 and 10."
                exit 1
            fi

            sample_names=("Grace Uwase" "Eric Mugisha" "Linda Keza" "Samuel Hakizimana" "Aline Mukamana" "David Nkurunziza" "Claudine Ingabire" "Patrick Niyonzima" "Sandrine Umutoni" "Kevin Byiringiro")
            sample_emails=("grace@example.com" "eric@example.com" "linda@example.com" "samuel@example.com" "aline@example.com" "david@example.com" "claudine@example.com" "patrick@example.com" "sandrine@example.com" "kevin@example.com")

            echo "Email,Names,Attendance Count,Absence Count" > "$project_dir/Helpers/assets.csv"
            for ((i = 0; i < student_count; i++)); do
                echo "${sample_emails[$i]},${sample_names[$i]},0,0" >> "$project_dir/Helpers/assets.csv"
            done
            total_sessions=1
            echo "  Generated $student_count students with zero prior sessions."
            ;;
        *)
            echo "ERROR: Please choose A or B."
            exit 1
            ;;
    esac
}

update_thresholds() {
    echo ""
    read -p "Update the attendance alert thresholds? [y/N]: " update_answer

    if [ "$update_answer" != "y" ] && [ "$update_answer" != "Y" ]; then
        echo "  Keeping the default thresholds (warning 75, failure 50)."
        return
    fi

    read -p "New warning threshold (default 75): " new_warning
    if ! [[ "$new_warning" =~ ^[0-9]+$ ]]; then
        echo "ERROR: The warning threshold must be a number."
        exit 1
    fi

    read -p "New failure threshold (default 50): " new_failure
    if ! [[ "$new_failure" =~ ^[0-9]+$ ]]; then
        echo "ERROR: The failure threshold must be a number."
        exit 1
    fi

    if [ "$new_failure" -ge "$new_warning" ]; then
        echo "ERROR: The failure threshold must be lower than the warning threshold."
        exit 1
    fi

    sed -i "s/\"warning\": [0-9]*/\"warning\": $new_warning/" "$project_dir/Helpers/config.json"
    sed -i "s/\"failure\": [0-9]*/\"failure\": $new_failure/" "$project_dir/Helpers/config.json"
    echo "  Thresholds updated: warning $new_warning, failure $new_failure."
}

run_project() {
    if [ -z "$project_dir" ]; then
        read -p "Enter the project name to run: " project_name
        project_dir="attendance_tracker_${project_name}"
    fi

    if [ ! -d "$project_dir" ]; then
        echo "ERROR: '$project_dir' does not exist. Deploy it first."
        exit 1
    fi

    if [ ! -f "$project_dir/attendance_checker.py" ]; then
        echo "ERROR: '$project_dir' is missing attendance_checker.py."
        exit 1
    fi

    echo ""
    echo "Starting the attendance session in '$project_dir'..."
    echo "-------------------------------------------------"
    ( cd "$project_dir" && python3 attendance_checker.py )
    echo "-------------------------------------------------"
    echo "Attendance session finished."
}

archive_logs() {
    if [ -z "$project_dir" ]; then
        read -p "Enter the project name to archive: " project_name
        project_dir="attendance_tracker_${project_name}"
    fi

    if [ ! -d "$project_dir" ]; then
        echo "ERROR: '$project_dir' does not exist."
        exit 1
    fi

    timestamp=$(date +"%Y%m%d_%H%M%S")
    archived_any=0

    echo ""
    echo "Archiving logs from '$project_dir'..."

    if [ -f "$project_dir/reports/attendance.log" ]; then
        mkdir -p "$project_dir/archives/attendance"
        cp "$project_dir/reports/attendance.log" "$project_dir/archives/attendance/attendance_${timestamp}.log"
        echo "  Archived: $project_dir/archives/attendance/attendance_${timestamp}.log"
        archived_any=1
    else
        echo "  Skipped: reports/attendance.log does not exist."
    fi

    if [ -f "$project_dir/reports/absent.log" ]; then
        mkdir -p "$project_dir/archives/absent"
        cp "$project_dir/reports/absent.log" "$project_dir/archives/absent/absent_${timestamp}.log"
        echo "  Archived: $project_dir/archives/absent/absent_${timestamp}.log"
        archived_any=1
    else
        echo "  Skipped: reports/absent.log does not exist (nobody was absent)."
    fi

    if [ "$archived_any" -eq 0 ]; then
        echo "Nothing was archived. Run the application first."
    else
        echo "Archiving complete."
    fi
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

    echo "Copying application files..."
    cp templates/attendance_checker.py "$project_dir/attendance_checker.py"
    cp templates/config.json "$project_dir/Helpers/config.json"
    echo "  Copied: attendance_checker.py"
    echo "  Copied: config.json"

    build_roster

    sed -i "s/\"total_sessions\": [0-9]*/\"total_sessions\": $total_sessions/" "$project_dir/Helpers/config.json"
    echo "  Set total_sessions to $total_sessions to match the roster."

    update_thresholds

    echo "Setting permissions..."
    chmod +x "$project_dir/attendance_checker.py"
    chmod 600 "$project_dir/Helpers/config.json"
    echo "  attendance_checker.py  -> executable (+x)"
    echo "  Helpers/config.json    -> owner read/write only (600)"

    echo ""
    echo "Deployment complete. Verifying by running the application..."
    run_project
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
        run_project
        ;;
    3)
        archive_logs
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
