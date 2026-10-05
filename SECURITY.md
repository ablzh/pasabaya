# Security reporting

Security fixes target the current `main` branch. Release branches do not have a
separate backport policy.

Report vulnerabilities privately through this repository's GitHub Security tab
when private vulnerability reporting is available. If it is unavailable, open a
minimal issue asking the maintainer for a private reporting channel, without
exploit details or personal data. The maintainer must enable and verify private
reporting in repository settings; this document does not enable it.

Include the affected code or feature, reproduction steps, likely impact, and a
suggested fix if known. Use local test accounts and redact credentials, session
cookies, email addresses, and chat content. Do not test against other users or
production data.

Development/demo passwords are documented for disposable local databases.
Production seeds exclude those accounts. Deployment credentials remain in Rails
encrypted credentials; only the decryption key belongs in the operator's secret
store or an untracked key file. Review infrastructure access and recovery using
[the operations guide](docs/operations.md).

Registration has a honeypot, and account creation, outgoing account emails, and
authenticated creation actions have rate limits. These reduce automated abuse;
they do not verify identity or email ownership. Current thresholds and cache/IP
requirements are documented in [abuse protection](docs/operations.md#abuse-protection).
