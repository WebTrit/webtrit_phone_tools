# The backend a build talks to

This tool decides it, and nothing that calls the tool can override it. The
address is a constant here:

```dart
// lib/src/constants.dart
const configuratorProdApiUrl = 'https://configurator-backend-v2-...a.run.app/v1';
```

So the revision of this repository that a build checks out is the choice. That
matters because there are two configurator backends in service at once, and a
credential issued by one means nothing to the other.

## The two revisions

| Branch | Backend it talks to | For |
|---|---|---|
| `main` | Cloud Run, `configurator-backend-v2-...` | brands configured in the current configurator |
| `legacy/firebase-backend` | Firebase, `us-central1-webtrit-configurator.cloudfunctions.net` | configurators deployed before the move, whose release is still being tested |

`legacy/firebase-backend` is frozen at the last commit that faced the Firebase
backend - `57788c7`, the font-asset change. Nothing lands on it; if something
ever has to, it is a cherry-pick and a deliberate one.

## An address override is not enough

There is one - `WEBTRIT_CONFIGURATOR_API_URL` - and it is meant for pointing a
run at another deployment of the **same** shape: a debug instance, a local
stack. It does not turn `main` into the old client.

What changed with the backend was the conversation, not only the address.
`configurator-resources` now fetches everything a build needs in a single request
to `/build/applications/:id/bundle`, where the service has already chosen the
theme, resolved the appearances and named the path each file belongs to. The
Firebase backend has no such endpoint, and the older revision instead made a
series of calls and did that assembling itself. Two shapes, two revisions.

## The picker

Nobody picks it by hand in practice. The builder has one workflow per era
(`build_phone.yml` frozen on this branch, `build_phone_v3.yml` on `main`), and
each configurator dispatches the one that matches it. The builder's own account
of it is [two-tracks.md](https://github.com/WebTrit/webtrit_phone_builder/blob/main/docs/architecture/two-tracks.md).

## The end of it

When the release under test ships and no deployed configurator asks for the
Firebase backend any more: this branch, the frozen workflow and that backend go
together. Until then the branch exists so that nothing lands on it by accident.
