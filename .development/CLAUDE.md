# Project Instructions for Claude Code

## C# Coding Rules Hook

This project has a PostToolUse hook that checks for C# coding rule violations after every Edit/Write operation.

**When the hook reports violations:**
1. Immediately fix ALL reported violations by editing the file
2. Do not ask for permission before fixing
3. After fixing, present the changes to the user for their review
4. The user will approve or reject your edits

The hook is deterministic and will catch violations every time, so always fix them when reported.
