# identity_service

Layer 2 headless identity capability for authentication and user-profile operations.

## Responsibility

`IdentityService` exposes identity state and operations such as email/password and Google authentication, profile retrieval and display-name updates. The package contains service contracts, provider integration and Firebase-backed implementation. It has no screens or app routes; `identity_product` owns the user-facing identity flows.

## Layer boundary

The service depends on Layer 1 contracts and infrastructure SDKs. It must not depend on a product or the app. Products may consume this reusable capability directly without depending on `identity_product`.

## Use

```yaml
dependencies:
  identity_service:
    git:
      url: https://github.com/mahafez-app/identity_service.git
      ref: v1.1.0
```

Import `package:identity_service/identity_service.dart` for the supported service contract and provider API.
