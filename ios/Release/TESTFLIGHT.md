# TestFlight release

Turing Twist uses the existing Apple account in Xcode on this Mac:
- Team: `SD8D6GX2BC`
- Bundle ID: `com.justinpaulson.turingtwist.ios`
- App Store Connect app: `6799463958`

## Automatic releases

Every push to `main` runs the Rails checks, deploys the backend, and then runs the `testflight` job in `.github/workflows/deploy.yml`. Pull requests never run the self-hosted release job. A failed check or backend deployment prevents upload.

The dedicated `mac-mini-runner-turing-twist` runner uses the `turing-twist` label. It runs as a launch agent under the owner's account, like the other iOS runners. This Mac must be awake and its signing keychain available. Xcode must remain signed into the Apple account; renew expired sessions in Xcode Settings > Accounts.

`script/testflight` validates native model decoding, builds the simulator app, archives the exact CI commit, and uploads with automatic signing. Build numbers use `<GitHub run number>.<run attempt>` (for example `105.1`), so reruns do not collide and no build-number commit is required. Keep manual build numbers below the next CI run number or adjust this convention before a manual upload.

The Actions job summary confirms upload acceptance and links to App Store Connect. Apple processing is separate; verify the build is available to the existing Internal Testers group after processing. An upload does not submit an App Store release or external beta review.

## Local validation

```sh
xcrun swiftc ios/TuringTwist/Models.swift ios/Tests/ModelDecodingTests.swift -o /tmp/turing-model-tests
/tmp/turing-model-tests
```

The local single-player release candidate was archived as 1.0 (3), but the shipped CI build uses its run/attempt number. What to Test copy is in `WhatToTest.txt`.
