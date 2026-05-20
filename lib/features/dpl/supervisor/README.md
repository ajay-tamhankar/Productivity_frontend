# DPL Supervisor Module (Phase 2)

Shop-floor execution UI for the `dpl_supervisor` role. Lets a supervisor
see today's plans, start/stop items with server-side timestamps, log and
resume downtimes, and submit the end-of-shift summary.

## Folder layout

```
lib/features/dpl/supervisor/
├── providers/
│   ├── today_plans_provider.dart          # GET /supervisor/today (polled every 30s) + global active-downtime derived
│   ├── machine_plan_provider.dart         # GET /supervisor/plans/:id (family by planId)
│   ├── live_timer_provider.dart           # Ticking Duration derived from a server start_time
│   ├── downtime_provider.dart             # cached downtime-reasons list
│   └── shift_summary_provider.dart        # GET /supervisor/shift/summary?date=
├── screens/
│   ├── supervisor_shell.dart              # bottom nav: Today | Shift Summary | Profile
│   ├── supervisor_dashboard_screen.dart   # large machine tiles
│   ├── machine_plan_screen.dart           # per-plan items + active downtime banner
│   ├── plan_execution_screen.dart         # the core START/STOP/RESUME state machine
│   └── shift_summary_screen.dart          # end-of-shift roll-up + submit
├── widgets/
│   ├── machine_tile_large.dart            # big tappable tile with built-in DT sub-banner
│   ├── live_timer_text.dart               # mm:ss / hh:mm:ss live counter
│   ├── plan_row_card.dart                 # row in MachinePlan
│   ├── start_stop_button.dart             # 64dp primary action button + haptics
│   ├── downtime_banner.dart               # global sticky red bar (mounted in shell)
│   ├── downtime_entry_sheet.dart          # bottom sheet for opening a downtime
│   ├── stop_confirm_dialog.dart           # confirm + actual_qty + remarks
│   └── supervisor_error_helper.dart       # code-based dialog/snackbar mapping
└── README.md
```

## Conventions (matched from Phase 1)

| Concern | Pattern |
|---|---|
| State mgmt | Plain Riverpod (`FutureProvider`, `StreamProvider`, `NotifierProvider`, `Provider.family`) — **no codegen** |
| Models | Manual JSON parsing via the helpers in [`models/_json_helpers.dart`](../models/_json_helpers.dart) |
| HTTP | The same `dplDioProvider` + `DplApiService._send<T>` envelope pipeline — 11 new methods appended at the bottom of `DplApiService` |
| Error envelope | `DplApiResponse<T>` — UI calls `handleSupervisorError(...)` for code-based branching (`ITEM_ALREADY_RUNNING`, `ACTIVE_DOWNTIME_EXISTS`, etc.) |
| Shimmer / shells | Reuses `SkeletonList`, `DplStatusBadge`, `DplEmptyState`, `DplErrorRetry`, `DplSnack` from Phase 1 |
| Bottom nav | `IndexedStack` + `NavigationBar` (same as `manager_shell.dart`) |

## What's not in this phase (deferred to Phase 3)

- WebSocket / push refresh (we poll `/today` every 30s instead).
- Multi-shift handoff.
- Offline queue / photo capture.
- A standalone `plan_execution_provider` — the source of truth is the
  per-plan `machinePlanProvider`; the execution screen reads from it and
  calls the API methods directly (mirroring Phase 1's plan-detail flow).
  This keeps state coherent across screens with one fetch.

## Endpoints used (11 total)

| Method | Path | Method on `DplApiService` |
|---|---|---|
| GET | `/supervisor/today` | `supervisorToday()` |
| GET | `/supervisor/plans/:id` | `supervisorGetPlan(id)` |
| POST | `/supervisor/plans/:planId/items/:itemId/start` | `startItem(planId, itemId)` |
| POST | `/supervisor/plans/:planId/items/:itemId/stop` | `stopItem(planId, itemId, actualQty, remarks)` |
| PATCH | `/supervisor/plans/:planId/items/:itemId/actual` | `updateActualQty(planId, itemId, qty)` |
| POST | `/supervisor/plans/:planId/downtime/start` | `startDowntime({planId, machineId, reasonId, ...})` |
| POST | `/supervisor/downtime/:downtimeId/resume` | `resumeDowntime(downtimeId)` |
| GET | `/supervisor/plans/:planId/downtimes` | `listPlanDowntimes(planId)` |
| GET | `/supervisor/shift/summary?date=` | `shiftSummary(date)` |
| POST | `/supervisor/shift/submit` | `submitShift(date, remarks)` |
| GET | `/supervisor/downtime-reasons` | `supervisorDowntimeReasons()` |

## Routes

| Path | Screen |
|---|---|
| `/dpl/supervisor` | `SupervisorShell` (3-tab bottom nav) |
| `/dpl/supervisor/machine/:planId` | `MachinePlanScreen` |
| `/dpl/supervisor/machine/:planId/execute/:itemId` | `PlanExecutionScreen` |

## Added packages

```yaml
wakelock_plus: ^1.2.5   # keep screen awake during active production
```

The Phase 1 dependencies (`file_picker`, `dio`, `fl_chart`, `intl`,
`share_plus`, `excel`, `pdf`, `flutter_riverpod`, `go_router`,
`shared_preferences`) are reused as-is.

## Live timer rule (important)

`liveTimerProvider(startTime)` is family-keyed by the **server-issued
`start_time`** and computes `DateTime.now().toUtc().difference(start.toUtc())`
on every tick. We never accumulate a counter locally, so the displayed
elapsed time stays correct across:

* Hot-reload
* Backgrounding the app
* Reading the same downtime/item from two screens at once
* Device-clock drift (we normalise to UTC)

## Error-code mapping

`handleSupervisorError(context, response)` centralises the dialog /
snackbar for the business-rule codes spelled out in the backend spec:

* `ITEM_ALREADY_RUNNING` → dialog with optional "Go to running item"
* `ACTIVE_DOWNTIME_EXISTS` → info snackbar
* `RESOLVE_DOWNTIME_FIRST` → dialog
* `INCOMPLETE_ITEMS` → dialog (blocks shift submit)
* `NOT_YOUR_PLAN` → error snackbar + pop screen
* `FORBIDDEN_ROLE` → error snackbar (Dio interceptor handles the
  auto-logout)

## Out of scope here

Manager flows (Phase 1) are untouched. The router redirect already
sends `dpl_supervisor` accounts to `/dpl/supervisor`; no auth changes
were needed.
