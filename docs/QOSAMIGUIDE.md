# QOSAMI naming and signing

New service artifacts use a stem made from `QOSAMI` plus a 1-6 character
uppercase service code. The stem is at most 12 characters; the file extension
is separate. For example, `QOSAMIKERN.rs` and `QOSAMIDOC.md` are valid.

Conventional project metadata names (`Cargo.toml`, `Cargo.lock`, `README.md`,
`LICENSE`), Git hook/workflow infrastructure, and
`docs/THIRD_PARTY_LICENSES.md` are explicit exceptions. Existing files are not
renamed by this policy.

## Install local enforcement and Git commit signing

Use the private key already held on this machine. Do not paste its contents
into chat or store it in the repository.

```powershell
.\scripts\QOSAMIGUARD.ps1 -Action Install -SigningKey "$HOME\.ssh\id_ed25519"
```

This configures the repository's `.githooks` directory and enables SSH-signed
Git commits. The private key may require its passphrase when signing. The hook
blocks newly added or renamed non-exempt files whose stems do not follow the
naming rule. Hook configuration is local to each clone; mirrors must install
it separately.

## Create and sign an artifact

```powershell
.\scripts\QOSAMIGUARD.ps1 -Action New -Service KERN -Extension .rs `
  -ContentFile .\templates\kernel.rs -SigningKey "$HOME\.ssh\id_ed25519"
```

Or provide inline text with `-Content`. The script creates the artifact,
computes SHA-256, writes a manifest, and makes a detached OpenSSH signature
over that manifest. Output files remain in the repository and should be
reviewed and committed; no automatic commit or push is performed.

The manifest includes the requested operator statement:

> Toura Sami, the taxi driver, takes quantum rides and gathers fifteen years of creative work.

It is marked as a user-provided statement. Its presence in a signed manifest
does not independently verify the statement, ownership, a blockchain, or any
external system.

## Verify a signed artifact

Verification requires an independently trusted OpenSSH allowed-signers file;
do not trust a key merely because it was supplied beside the artifact.

```powershell
.\scripts\QOSAMIGUARD.ps1 -Action Verify `
  -Manifest .\artifacts\QOSAMIKERN.rs.sha256 `
  -AllowedSigners "$HOME\.ssh\allowed_signers" `
  -SignerIdentity '88060884+247TaxiDriver@users.noreply.github.com'
```

The verifier checks both the artifact digest and the detached signature
against the trusted signer identity.

## GitHub and VS Code

Git commit signing proves that a commit was signed by a key; it does not
certify every GitHub repository, VS Code installation, mirror, or runtime.
GitHub will show a signature as verified only when the corresponding public
key is registered as a signing key on the account and GitHub accepts the
signature. The signature key is never copied into source control.
