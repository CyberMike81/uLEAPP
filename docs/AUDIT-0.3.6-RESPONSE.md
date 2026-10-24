# 0.3.6 audit follow-up

The 0.3.7 changes address C-E through C-I; optional suggestions and earlier open
hardware/licensing questions are outside this patch.

- C-E: Apple-anchored publisher team requirement, Gatekeeper execution assessment
  and quarantine before publishing direct copies. Launch also verifies/quarantines
  pre-existing direct copies. Native integration asserts these properties.
- C-F: dual version display and selected-copy explanation; explicit Return to
  Homebrew with catalogue preflight, actual bundle-version/publisher checks, and
  record removal only after success. Copies are retained.
- C-G: PostDeleteItem must identify a successful new Recycle Bin item. Fixed local
  drives only; known no-recycle policy/per-volume settings refuse the operation.
  No permanent-delete API fallback. Hardware policy/quota tests remain manual.
- C-H: persisted automatic-check opt-out plus --no-update-check on all platforms;
  conditional ETag requests and quota/reset diagnostics. A 304 is quota-exempt
  only for an authenticated request, so ETags do not eliminate the unauthenticated
  per-IP limit. No offline cached-success fallback is used.
- C-I: the live Homebrew test selects an actually Homebrew-managed cask for its
  controlled minimum-version assertion, or explicitly skips that assertion.
