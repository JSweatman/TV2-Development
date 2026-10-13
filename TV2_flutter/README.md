# List Number TV2 Flutter client — connected-client checkpoint

The mobile scaffold no longer contains a production-path hardcoded identity resolver. It calls the TV2 resolver API for progressive matches and exact listings.

## Configuration
The API URL is supplied at build/run time:

```bash
flutter run --dart-define=TV2_API_BASE_URL=http://10.0.2.2:8000 --dart-define=TV2_DEFAULT_COUNTRY=1
```

`10.0.2.2` is the common Android-emulator route to the host computer. A different address is normally required for an iOS simulator or a physical device.

## Implemented in source
- Frozen 16-key keypad layout.
- Country-context test control.
- 250 ms progressive-resolution debounce.
- Stale-response suppression using a request generation number.
- Exact versus prefix results.
- Backend-driven listing and resource model.
- Generic template/resource display; no fixture-specific UI logic.
- CALL failure wording when no call capability exists.
- Loading, timeout, unavailable-server, invalid-response, and backend-error states.

## Not yet verified here
No Flutter or Dart SDK is installed in the current execution environment, so the client source and tests have **not** been compiled or run at this checkpoint. That remains a quality gate before handoff.

External URL launching and real CALL/VIDEO/TEXT session adapters are deliberately separate from resolution and are not live in this checkpoint.
