# Feature 01: Auth, Session, and Email OTP

## Scope And Dependencies

Includes splash/session bootstrap, email register/login, Google login, OTP send/verify/resend, refresh-token handling, and logout.

## Contract Readiness

Status: `Ready for mobile`. Register/login/Google/refresh and OTP DTOs are source-validated. No mobile behavior in this feature requires an unresolved backend action.


Depends on:

- App router and authenticated shell.
- Dio client and secure storage.
- Identity Service through the Gateway.

## Current Web Behavior To Preserve

- Registration collects account fields, submits them, stores the returned email for verification, and opens the OTP surface.
- Registration response includes `otpSent`. Web starts a 60-second resend countdown only when it is true; otherwise resend is immediately available.
- OTP UI has six boxes, accepts numeric typing and a pasted six-digit code, moves focus between cells, and auto-submits after all six digits exist.
- Verify is disabled while incomplete or pending.
- Resend is disabled while sending and during the 60-second cooldown.
- Successful verification shows a success state and currently redirects after a short countdown.
- Login supports email/password and routes unverified accounts to OTP.
- Google login sends the Google `idToken` to Kirenz and stores only Kirenz tokens.
- Logout clears local tokens and authenticated state.

Web discrepancy mobile must correct:

- Web labels its 60-second resend countdown as code expiry. Backend OTP validity is five minutes. Mobile must show `Resend in 00:SS` for the cooldown and only describe five-minute expiry separately.

## Backend Contracts

| Action | Contract |
| --- | --- |
| Register | `POST /api/auth/register`; use returned email and `otpSent`. |
| Login | `POST /api/auth/login`. |
| Google login | `POST /api/auth/google { idToken }`. |
| Refresh | `POST /api/auth/refresh`. |
| Send OTP | `POST /api/verification/send-otp { email }`. |
| Verify OTP | `POST /api/verification/verify-otp { email, otp }`. |

OTP is six numeric digits, single-use, stored for five minutes, and send is rate-limited for 60 seconds per email.

Exact request/response `data` shapes:

```text
RegisterRequest { email, username, password, displayName }
RegisterResponse { id, email, username, displayName, createdAt, otpSent }
LoginRequest { email, password }
GoogleLoginRequest { idToken }
RefreshTokenRequest { refreshToken }
LoginResponse { accessToken, refreshToken, tokenType, expiresIn }
SendOtpRequest { email }
SendOtpResponse { message }
VerifyOtpRequest { email, otp }
VerifyOtpResponse { message, emailVerifiedAt }
```

Registration validation is source-owned: email 5-255 characters and valid format, username 3-50 characters with the backend username pattern, password at least 8 characters, and optional display name 1-100 characters. Mobile may validate earlier but must still render backend field errors.

## Routes

| Route | Purpose |
| --- | --- |
| `/splash` | Restore session and select authenticated/unauthenticated route. |
| `/login` | Email/password and Google login. |
| `/register` | Registration form. |
| `/verify-otp?email=...` | Verification; email is also retained in controller state so it is not lost on rebuild. |

Authenticated users must not return to login/register through normal back navigation. Unauthenticated users hitting a protected route return to login with an optional intended destination.

## Screen And Behavior Specification

### Splash/session bootstrap

1. Read access/refresh tokens from secure storage.
2. If absent, route to Login.
3. If access token is usable, bootstrap current user, then connect realtime services.
4. If expired, perform one refresh, persist new tokens, then bootstrap.
5. If refresh fails, clear all session data and route to Login.
6. Keep a branded splash visible while the decision is pending; never flash Home before redirecting to Login.

### Login

- Pill email and password inputs; password visibility toggle.
- Email keyboard/autofill and password autofill.
- Field validation appears under its field and clears when edited.
- Submit is disabled while pending.
- Invalid credentials map to the most useful field; transport/server errors use a form-level message.
- Google button is independent of email/password validation.
- If backend reports unverified email, retain email and route to OTP.

### Register

- Validate each field locally without replacing backend validation.
- Preserve entered values after a recoverable failure; do not preserve passwords after leaving the flow.
- After success:
  - `otpSent=true`: route to OTP and start 60-second resend cooldown.
  - `otpSent=false`: route to OTP, explain that automatic delivery failed, and enable Send code.
- Back asks before discarding a completed form only when meaningful input would be lost.

### OTP

- Present six visual cells backed by one logical numeric input.
- Enable iOS/Android one-time-code autofill and paste.
- Typing digit seven replaces/ignores according to normal max-length behavior; non-digits are ignored.
- Auto-verify at six digits only once. Prevent duplicate auto-submit plus button submit.
- While verifying, lock input and show progress on Verify.
- Invalid code: keep email, clear or select the code, show error below cells, refocus.
- Expired code: show expired message and enable resend subject to backend rate limit.
- Already verified: treat as completed and route to Login/Home based on available session.
- Resend success clears stale errors/code and starts 60 seconds.
- Rate limit uses backend message; countdown remains presentation only.
- Delivery failure keeps Resend available and does not claim success.
- Successful verification clears OTP state and replaces the route so Back cannot reopen a verified code.

### Token refresh

- Attach Bearer access token to protected REST calls.
- On 401, allow only one refresh request; queue other failed requests.
- Retry each queued request once with the new access token.
- Do not refresh verification/public endpoints unnecessarily.
- If refresh fails, cancel queued requests, disconnect sockets, clear user cache/tokens, and route to Login.

### Logout

- Disable repeated taps.
- Disconnect chat and notification sockets.
- Clear access token, refresh token, current user id, feature controllers, drafts that are user-private, and user-specific cache.
- Route to Login using route replacement.

## Controller State

```text
AuthState
  bootstrapStatus
  sessionStatus: unknown | authenticated | unauthenticated
  currentUser
  formPendingAction
  fieldErrors
  formError
  otpEmail
  otpWasAutoSent
  otpCooldownEndsAt
```

Use an absolute cooldown end time so app pause/resume does not reset or extend 60 seconds.

## Error And Edge Behavior

- No network: keep form/code and expose Retry.
- App resumes during OTP: recompute cooldown from end time.
- User changes account while refresh is pending: ignore stale completion by session generation/user id.
- Multiple 401 responses: one refresh only.
- Google cancellation is neutral, not an error banner.
- Never log passwords, OTP, Google token, access token, or refresh token.

## Behavior Completion Checklist

- [ ] Splash never flashes the wrong authenticated state.
- [ ] Email/password and Google login preserve current web capability.
- [ ] Register handles both `otpSent=true` and `false`.
- [ ] OTP typing, paste, autofill, auto-submit, manual submit, resend, expiry, and rate limit are defined exactly as above.
- [ ] Refresh queues concurrent 401 requests and retries once.
- [ ] Logout clears user state and both realtime connections.
- [ ] Every pending and failure state remains actionable.
