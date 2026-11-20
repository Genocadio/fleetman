# fleetman

Flutter fleet-management app for CavGo. Sign-in uses **Nexxauth** (the same
flow as twese-web / twese-android), and only approved **Fleet Managers** can
use the app.

## Authentication configuration

Nexxauth is a separate identity host. Fleetman authenticates directly against:

- `POST https://auth.nexxserve.dev/cavgo/auth/login`
- `POST https://auth.nexxserve.dev/cavgo/auth/refresh`
- `POST https://auth.nexxserve.dev/cavgo/auth/logout`

Every Nexxauth call requires a **public Fleetman client key** in the
`X-Client-Id` header. Register an ANDROID client in the Nexxauth console and
pass its key at build time:

```bash
flutter run --dart-define=NEXXAUTH_CLIENT_ID=cli_<fleetman-client-key>
flutter build apk --dart-define=NEXXAUTH_CLIENT_ID=cli_<fleetman-client-key>
```

The client key is never committed. CI reads it (and the two endpoints below)
from GitHub Secrets and passes them as `--dart-define` arguments.

`NEXXAUTH_ORIGIN` defaults to `android://com.example.fleetman` and can be
overridden with another `--dart-define` if the client is registered with a
different origin.

Do **not** use the backend's `NEXXAUTH_CLIENT_ID` / `NEXXAUTH_CLIENT_TOKEN`
from `cavgobackend/.env.example` — those are server-side credentials.

Backend and Nexxauth origins follow twese-android's CI variable names and are
injected at build time, with safe local defaults:

| Define | Default |
| --- | --- |
| `CAVGO_BASE_URL` | `https://api.gocavgo.com` (canonical gateway, no `/api` prefix) |
| `NEXXAUTH_BASE_URL` | `https://auth.nexxserve.dev/cavgo` |

## Fleet Manager gate

After Nexxauth login, the app calls `POST /main/users/sync` to resolve company
membership and effective role. Access is granted only when the user has the
`fleet_manager` role **and** an approved company membership.

Other signed-in users are shown a role/access request screen:

- Existing requests are checked with `GET /main/company-access-requests/my-status`
  (HTTP 204 means no request) before anything is submitted, and again
  immediately before `POST /main/company-access-requests`. PENDING requests
  cannot be duplicated; the screen polls every 20 seconds while awaiting
  approval.
- A company-access request preserves an existing Nexxauth staff role on
  approval. Users without a staff role must have `FLEET_MANAGER` granted by an
  administrator in Nexxauth before they can request company access.

## Request approval inbox

An approved Fleet Manager can review and act on requests for **their own
company only**. Open the profile dock (avatar in the bottom bar) and choose
**Requests** — the screen uses the same gradients, cards, dock menu, dialogs and
top toasts as the rest of the app.

It merges two queues, newest first, with a Pending / All filter:

- Role/company-access requests — `GET /main/company-access-requests/company/{companyId}[/pending]`
- Driver requests — `GET /main/driver-requests/company/{companyId}[/pending]`

Each card shows the requester, contact, request type, requested role, company
and date. **Approve** asks for confirmation and calls
`POST /main/company-access-requests/{id}/approve` or
`POST /main/driver-requests/{id}/approve`. **Reject** opens a dialog with an
optional reason and posts `{"reason": "..."}` to the matching `/reject`
endpoint. Approving a role request grants the requested role; non-staff users
become `WORKER`.

The gateway enforces company scope and role (`FLEET_MANAGER`, `SUPERVISOR` or
`ADMIN`) on every call and refuses self-approval or stale (non-PENDING)
requests. If the driver queue is unavailable the role-access queue still loads.
Already-handled requests get a friendly message, but a failed action is never
retried or auto-refreshed — the list is only refreshed after a successful
approve/reject. The acting card shows an action-specific skeleton and both
buttons stay disabled while a request is in flight. Pull down to refresh the
list; there are no refresh icon buttons. A 403 is shown as a
permission error without signing the manager out; a 401 signs the user out.
Errors use **Dismiss**, not **Retry**.

## Offices

From the profile dock choose **Offices** to see the company's offices and add
new ones. The screen lists offices from `GET /main/offices?companyId=...` with
their generated office code and location, and exposes a **New Office** form.

The form collects:

- **Name** (required) and a **location** (required), picked from the cavgotrips
  locations already synced into Fleetman's local database via
  `SyncRepository.searchLocations()`. The selected location's `id`, coordinates,
  place name, custom name and place id are sent with the request.
- Optional email, phone, address, city, contact emails and contact phones.

Creation posts to `POST /main/offices`. The `companyId` in the payload comes
from `CredentialsManager` (the signed-in manager's session) — there is no
company selector, so a manager cannot create an office for another company.
Backend validation errors (for example a missing `name` or `locationId`) are
shown in the form, a 401 signs the user out, and a successful create refreshes
the list and shows the usual top toast.

> Note: `cavgocompany` has no office-creation UI, and the backend currently
> accepts `POST /main/offices` from any authenticated user. Fleetman enforces
> the manager-only flow client-side; server-side role/company hardening is a
> separate backend change.

## Vehicle registration

From the profile dock choose **Register Vehicle**. The form collects make,
model, license plate, capacity (seats), vehicle type, device public key and an
optional initial status (default `AVAILABLE`), with client-side validation that
mirrors the backend.

Registration posts to `POST /main/vehicles` with exactly these fields:
`make`, `model`, `pubKey`, `capacity`, `licensePlate`, `vehicleType` and
`status`. **No `companyCode` or `companyId` is sent**: the backend resolves the
company from the authenticated manager's approved membership. The form still
requires a company session before it will submit, and there is no company
selector.

The response's `initialPassword` is displayed once on a success screen with a
copy hint and a **Done** button; it is not stored after the screen closes.
Validation errors, duplicate plates, 403 permission errors, 401 session expiry,
network failures and 5xx responses all get explicit messages. There is no
automatic retry: failures use **Dismiss**, and only a successful create leaves
the form. The submit button shows a skeleton placeholder and disables the form
while the request is in flight.

> Note: the backend does not currently restrict `POST /main/vehicles` to
> `FLEET_MANAGER` — an approved `DRIVER` or `WORKER` may also create a vehicle
> in their own company. Fleetman exposes this only to Fleet Managers; stricter
> server-side role enforcement is a separate backend change.

## CI and releases (GitHub Actions)

Repository: <https://github.com/Genocadio/fleetman>

The Android toolchain matches Flutter 3.50's template (Gradle 9.5.0, AGP 9.3.1,
Kotlin 2.4.20) and needs **JDK 21** for local builds too.

Two workflows are shipped, modelled on `twese-android`'s tag-driven release
workflow:

- `.github/workflows/ci.yml` — on pushes and PRs to `main`: `flutter analyze`,
  `flutter test`, then a debug APK uploaded as an artifact. Uses a placeholder
  client ID, so no secrets are needed.
- `.github/workflows/release.yml` — on a `v*` / `[0-9]*` tag: computes the
  version from the tag and commit count, injects the real client key with
  `--dart-define`, builds a release APK, verifies its signature with
  `apksigner`, and publishes the APK plus `update.json` (sha256) to GitHub
  Releases.

To cut a release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Add these repository secrets under **Settings → Secrets and variables →
Actions**:

| Secret | Required | Purpose |
| --- | --- | --- |
| `CAVGO_BASE_URL` | yes | gateway origin, e.g. `https://api.gocavgo.com` |
| `NEXXAUTH_BASE_URL` | yes | Nexxauth origin, e.g. `https://auth.nexxserve.dev/cavgo` |
| `NEXXAUTH_CLIENT_ID` | yes | public ANDROID Fleetman client key (`cli_...`) |
| `NEXXAUTH_ORIGIN` | no | defaults to `android://com.example.fleetman` |
| `KEYSTORE_BASE64` | no | base64 release keystore; without it Flutter's debug key is used |
| `KEYSTORE_PASSWORD` | no | release keystore password |
| `KEY_ALIAS` | no | release key alias |
| `KEY_PASSWORD` | no | release key password |

The keystore secrets are optional for building but should be set for anything
you distribute. They are decoded inside the runner into a git-ignored
`android/.gradle/keystores/` directory; no signing material is committed.

## UI conventions

- Sign-in has no visible role-check step. The Fleet Manager gate evaluates
  access in the background and shows a neutral skeleton until it knows which
  screen to present.
- Loading states use `AppSkeleton`, `AppSkeletonCard` and `AppSkeletonList`
  rather than circular progress indicators, including button busy states.
- Lists refresh by pulling down (`RefreshIndicator`). There are no refresh icon
  buttons in app bars or on the access screens.

## Session recovery

All authenticated data clients call `CredentialsManager.getAccessToken()`, which
refreshes proactively five minutes before expiry. Vehicle and trip requests also
retry **once** after an HTTP 401: they force a Nexxauth refresh through the same
single-flight path (so the single-use rotating refresh token is never consumed
twice) and replay the request with the new token. If the refresh fails, the
session is cleared and the user is returned to sign-in.

The location/route sync endpoints (`/navig/locations/hash`, `/navig/routes/hash`)
are public and send no token.

## Tests

```bash
flutter analyze --no-fatal-infos
flutter test
```

`--no-fatal-infos` is used because Flutter 3.50 reports informational lints
(project-wide `material.dart` deprecations and similar) that do not fail the
build; errors and warnings are still fatal.

The tests use `MockClient` from `package:http/testing.dart`; no live services or
build-time defines are required. They cover the Nexxauth login/refresh payloads,
the gateway access APIs, every Fleet Manager gate state, duplicate-request
prevention, 401 recovery, the request-queue endpoints and controller, the
approve/reject widget flows, and vehicle registration (wire body, validation,
one-time password, error handling and loading states).

## Live verification checklist

These require a real `cli_...` Fleetman client key plus test accounts, so they
cannot run in CI:

1. Fleet manager **with** a company → sign in → app unlocks to `HomeScreen`.
2. Fleet manager **without** a company → request form → submit → pending screen
   → approve in the staff console → app unlocks within 20 seconds (or via
   "Check again" / app resume).
3. Plain `customer` account → "Fleet Manager role required" screen; no company
   access request can be submitted.
4. Rejected request → rejection reason shown → "Request again" submits exactly
   one new POST.
5. Double-tap "Request access" / submit from two devices → only one PENDING
   request is created.
6. Revoke a session in Nexxauth, then use the app → next API call triggers a
   401, refresh fails, and the user lands on the sign-in screen.
7. As an approved manager, open **Requests** → a requester's pending card
   appears → **Approve** → the card moves out of Pending and the requester's
   gate unlocks on their next check.
8. Reject another request with a reason → the requester sees the reason in the
   "Access not approved" screen and can submit a fresh request.
9. Toggle **Pending / All** and pull to refresh; try approving the same request
   from two devices → the second attempt reports it was already handled.
10. Confirm a manager never sees another company's requests or can approve
    their own request.
11. Reject or approve a request while the network is unavailable, then confirm
    the card shows an error with **Dismiss**, no automatic retry, and the
    buttons are disabled only while the action is in flight.
12. As an approved manager, open **Register Vehicle** → submit a valid vehicle
    → confirm the device password appears once → verify the request body has no
    `companyCode` and the vehicle belongs to the manager's company.
13. Register a duplicate plate and a 403 case → confirm each error is shown
    with **Dismiss** and no retry, then submit again manually.

## Removed legacy files

The old native `AuthActivity.kt`, `CreateTripActivity.kt`, `RouteSearchParser.kt`,
`TripResponse.kt` roots and the stale `SYNC_API.md`, `TRIP_CREATION_GUIDE.md`
and `VEHICLE_DRIVER_SEARCH_AND_ASSIGNMENT_API.md` docs were removed. They were
not part of the Flutter build and referenced the retired `/api/main/auth/login`
endpoint. The `scratch/` helper scripts now default to `https://api.gocavgo.com`.
