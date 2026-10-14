# deploy_agent_brukundo-crypto

A shell script that deploys the Student Attendance Tracker, runs it, archives its logs, and cleans up after itself if a deployment gets interrupted.

## What is in the repo

deploy_agent.sh is the script. The templates folder holds the three original files from the assignment (attendance_checker.py, assets.csv, config.json), and .gitignore keeps the deployed test projects and zip files out of the repo.

## Requirements

bash, python3 and zip. The script checks for python3 and zip before it builds anything and stops with a clear message if either one is missing. It prints the python3 version so you can see which one it found.

## How to run the script

Open a terminal in the repo folder, since the script reads templates/ relative to where you are, then run:

```
chmod +x deploy_agent.sh
./deploy_agent.sh
```

## How to choose a feature

I used a menu instead of flags:

```
1) Deploy a new project
2) Run an existing project
3) Archive the log files
4) Exit
```

Type the number and press Enter. Options 2 and 3 ask for the project name, which is whatever comes after attendance_tracker_. If that folder doesn't exist the script says so and stops.

I went with a menu because the script asks questions the whole way through anyway, so flags would have been a mismatched style. The trade-off is that a menu can't be run from a cron job, but this is a tool for a person setting up a class, not something that needs to run on its own.

## Deploying a project

Option 1 asks for a project name and builds this:

```
attendance_tracker_<name>/
    attendance_checker.py
    Helpers/
        config.json
        assets.csv
    reports/
```

The steps, in order:

1. Check python3 and zip are installed, and print the python3 version.
2. Ask for the name. An empty name is rejected.
3. If the folder already exists, warn and ask before overwriting. The prompt is [y/N] so No is the default, and only y or Y goes ahead. Anything else aborts and leaves the old project alone.
4. Copy attendance_checker.py and config.json out of templates/ without changing them.
5. Ask how to build the roster, then how many students.
6. Set total_sessions in config.json to match the roster.
7. Offer the threshold update.
8. Set permissions: chmod +x on attendance_checker.py and chmod 600 on Helpers/config.json, and print what was set.
9. Start the app. If it starts, the structure, roster and config all work together.

For the roster, option A copies the header plus the first N rows of templates/assets.csv. Option B builds N rows from a list of 10 names and emails I defined in the script, with both counts at 0. Both options are capped at 1 to 10, because that's how many students the template has and how many names I defined. Asking for more would silently give you fewer rows in option A and blank rows in option B, so I reject it instead.

The app works out attendance percentages from total_sessions, which counts today's session, so it has to be one more than the sessions already in the roster. The template students each have 4 on record, so option A sets it to 5. A generated roster starts from zero, so option B sets it to 1. Either way the script writes it with sed, so there is no prompt for it. If the two files disagreed, the app would print a warning for every student and the percentages would come out wrong.

## How the threshold update works

After total_sessions is set the script asks "Update the attendance alert thresholds? [y/N]". Anything other than y or Y keeps the defaults and says so.

If I answer y, it asks for the warning (default 75) and then the failure (default 50). Before it touches the file it checks that both answers are digits only, and that the failure value is lower than the warning value, since a failure level above the warning level makes no sense.

If a check fails the script prints why and stops rather than writing a broken config. If both pass, sed -i changes only the "warning": and "failure": lines and nothing else, so the file keeps its original spacing and key order.

## How the log archiving works

Option 3 asks for the project name, takes one timestamp with date +%Y%m%d_%H%M%S, and copies each log into its own folder:

```
attendance_tracker_<name>/archives/
    attendance/attendance_20261012_165214.log
    absent/absent_20261012_165214.log
```

Both logs from one run share a timestamp so they are easy to match, and a later run gets new names so nothing is overwritten. The script prints where each file went. I used cp, so the originals stay in reports/.

absent.log only exists if someone was marked absent, so each log is checked before copying. If one is missing the script says it is skipping that file and carries on. If neither exists it says nothing was archived and suggests running the app first.

## Ctrl+C and Ctrl+Z during a deploy

While a project is being built the script traps Ctrl+C (SIGINT) and Ctrl+Z (SIGTSTP). When one arrives it prints that the deployment was interrupted, zips whatever exists into attendance_tracker_<name>_archive.zip in the folder I ran the script from, deletes the incomplete project folder, and exits with status 130.

I delete the folder as well as zipping it so there is no half-built project left behind for someone to trip over later. The zip is the record of what was there.

If nothing has been created yet, for example Ctrl+C at the name prompt, the script says there is nothing to clean up and touches nothing. The trap is turned off before the marking session starts, so Ctrl+C during attendance marking goes to the Python app instead of triggering the deployment cleanup.

To test it:

```
./deploy_agent.sh
```

Pick 1, enter a name like demo, let it create the folders, then press Ctrl+C (or Ctrl+Z) at the roster question. Then run:

```
ls
unzip -l attendance_tracker_demo_archive.zip
```

The zip is there and the attendance_tracker_demo folder is gone.

What is inside the zip depends on when I interrupt. At the roster question it holds attendance_checker.py, Helpers/config.json and an empty reports/, with no assets.csv yet. If I interrupt later, at the threshold question, Helpers/assets.csv is in there too.

## How I tested it

- I deployed with option A and 3 students, checked the roster held students with 4 prior sessions and that config.json read "total_sessions": 5. Then I deployed with option B and checked it read 1.
- I ran ls -l and confirmed attendance_checker.py came out as -rwxr-xr-x and Helpers/config.json as -rw-------.
- I ran a marking session with one student absent and checked the percentages (5/5 = 100%, 1/5 = 20% flagged URGENT, 3/5 = 60% flagged WARNING) and that both logs appeared in reports/.
- I archived the same project twice and confirmed two files with different timestamps, so nothing was overwritten. I also archived a project with no logs and confirmed it skipped both and said so.
- I interrupted a deploy with Ctrl+C and with Ctrl+Z, checked the zip was created and the folder was gone, and interrupted before entering a name to confirm it reports nothing to clean up.
- I tried an empty project name, letters instead of a student count, letters instead of a threshold, a failure value above the warning value, and a student count above 10. Each was rejected with its own message.
- I ran it on Ubuntu 20.04.

[Play Video](https://www.loom.com/share/b1a2f8508d1e4fbabc79275835136274)
