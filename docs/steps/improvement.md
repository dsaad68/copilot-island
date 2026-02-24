# Copilot Island Improvement Report

Date: 2026-02-23

## Summary

This report lists the most valuable feature additions identified from the current codebase.

## Recommended Features

1. Real-time session transcript updates (highest priority)
Current chat history loads once and does not stream new messages or tool output while a session is active. Add live updates using incremental parsing and file/socket-driven refresh.

2. Auto-refresh recent sessions list
Recent sessions are loaded only during setup checks and plugin install flows. Refresh history after session lifecycle events (especially `sessionEnd`) and/or via file watchers.

3. Resume-session fallback handling
Session activation currently depends on `sessionStart`. Add fallback logic to activate session state when the first prompt/tool event is received, including resumed sessions.

4. Multi-session support
Current session state is modeled as a single active session. Introduce per-session state keyed by session identifier (or equivalent) to support parallel Copilot CLI sessions.

5. Plugin management controls in menu
UI currently exposes install status and install action only. Add update/uninstall/version controls to match existing installer capabilities.

6. Approval UX and terminal handoff improvements
Approval flow currently routes back to terminal approval limitations. Improve clarity with explicit terminal handoff actions (for example, focus terminal) and cleaner approval-state messaging.

7. Session history explorer enhancements
History view is limited to a small recent subset. Add search/filter (repo/branch/cwd), sorting, and load-more/pagination.

8. System notifications for key events
Add notifications for pending approvals and error states so users can react without continuously watching the notch.

## Suggested Delivery Order

1. Real-time chat streaming
2. Recent-session auto-refresh
3. Resume-session fallback handling
4. Plugin management controls
5. Approval UX improvements
6. Session history explorer
7. Notifications
8. Multi-session architecture
