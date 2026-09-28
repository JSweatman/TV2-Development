# TV2 Local Verification Runbook

This is the PM-level sequence for proving each layer without AWS.

1. Run backend unit/contract tests: `cd backend && python -m pytest -q`.
2. Start fixture resolver: `TV2_REPOSITORY=fixture PYTHONPATH=src uvicorn app:app --host 127.0.0.1 --port 8000`.
3. Check readiness: open `http://127.0.0.1:8000/ready`.
4. Exercise progressive API: `/v1/prefix?country=1&input=529`.
5. Exercise exact API: `/v1/resolve?country=1&input=529`.
6. Confirm `/v1/resolve?country=1&input=91*529` returns the separate country namespace record.
7. Confirm `/v1/resolve?country=1&input=*529` returns the Global Code record.
8. Confirm missing identifiers return `not_found`, not invented suggestions.
9. In an environment with Flutter, run `flutter test` and then launch the client with `TV2_API_BASE_URL` pointed to the resolver.
10. Only after those pass, test PostgreSQL mode, then real devices, then cloud deployment.

A pass at one level does not imply a pass at the next level.
