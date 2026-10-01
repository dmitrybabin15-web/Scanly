# Scanly Release Checklist

## 1) Apple Developer / App Store Connect

- [ ] Create app in App Store Connect (`com.scanly.app`).
- [ ] Fill app metadata: name, subtitle, description, keywords, support URL, privacy URL, terms URL.
- [ ] Upload app icon/screenshots for iPhone sizes.
- [ ] Set age rating and export compliance (non-exempt encryption already set to NO in project).
- [ ] Add privacy nutrition labels (camera, photo library, purchase data, optional OCR/AI processing notes).

## 2) Subscriptions (App Store + RevenueCat)

- [ ] In App Store Connect, create auto-renewable subscription group.
- [ ] Create product(s) for Scanly Pro (e.g. monthly/yearly).
- [ ] In RevenueCat, add iOS app and map products from App Store Connect.
- [ ] Create entitlement id `pro` (must match app code).
- [ ] Create and activate current Offering with packages.
- [ ] Put `REVENUECAT_API_KEY` into Run scheme for local testing.

## 3) Legal and policy links

- [ ] Edit `Scanly/LegalURLs.plist` with production URLs:
  - `ScanlyPrivacyPolicyURL`
  - `ScanlyTermsOfUseURL`
- [ ] Confirm links open from Settings and Paywall.

## 4) AI parsing readiness

- [ ] Decide production strategy for Anthropic key:
  - direct key in app (not recommended for production), or
  - proxy/backend endpoint (recommended).
- [ ] If testing local direct mode, set `ANTHROPIC_API_KEY` in Run scheme.
- [ ] Validate fallback when key is absent (manual draft editing still works).

## 5) Device QA (must pass before submission)

- [ ] Fresh install: onboarding shown once.
- [ ] Scan flow: camera + photo import + OCR + save.
- [ ] Free limit: after 5 saves, paywall appears for non-Pro.
- [ ] Purchase in sandbox: subscribe, app unlocks Pro, restart app keeps Pro state.
- [ ] Restore purchases works for existing subscriber.
- [ ] Insights charts render with mixed categories/currencies.
- [ ] CSV export works and file opens correctly.
- [ ] PDF export works and includes localized headers.
- [ ] Privacy/Terms links open correctly.

## 6) Localization sanity check

- [ ] Verify key screens in each included locale: `en`, `de`, `fr`, `es`, `it`, `nl`, `pl`.
- [ ] Check long-string truncation on small devices.
- [ ] Check currency/date formats match locale expectations.

## 7) Release build and upload

- [ ] Set Signing Team in Xcode target.
- [ ] Archive Release build from Xcode.
- [ ] Validate archive (Organizer) and upload to App Store Connect.
- [ ] Assign build to subscription-ready version and submit for review.

## 8) Post-release monitoring

- [ ] Monitor RevenueCat customer info/entitlement activation.
- [ ] Monitor crash reports and App Store reviews.
- [ ] Track conversion free -> Pro and export feature usage.
