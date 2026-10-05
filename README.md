# identity_service

Layer 2 headless identity capability for authentication and user profiles.

`IdentityService` exposes current identity state, Google and email/password
authentication, profile retrieval and display-name updates. The Firebase
implementation and provider are included; consumers receive `UserProfile`
and `Result` contracts from Layer 1. The package contains no screens or routes.

Products should use this service directly for identity operations and must not
depend on `identity_product`.
