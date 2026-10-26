[CmdletBinding()]
param(
    [ValidateSet("New", "Verify", "Install")]
    [string]$Action = "New",
    [string]$Service,
    [string]$Extension,
    [string]$Content,
    [string]$ContentFile,
    [string]$Directory = "artifacts",
    [string]$Manifest,
    [string]$AllowedSigners,
    [string]$SignerIdentity,
    [string]$SigningKey
)

$ErrorActionPreference = "Stop"
$statement = "Toura Sami, the taxi driver, takes quantum rides and gathers fifteen years of creative work."
$repository = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $repository) {
    throw "Run this script from inside the SAMNAM Git repository."
}
$repository = [IO.Path]::GetFullPath($repository.Trim())

function Get-SshKeygen {
    $command = Get-Command ssh-keygen -ErrorAction Stop
    return $command.Source
}

function Get-SigningKeyPaths {
    param([string]$RequestedKey)

    if ([string]::IsNullOrWhiteSpace($RequestedKey)) {
        $RequestedKey = git -C $repository config --get user.signingkey
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($RequestedKey)) {
            throw "Pass -SigningKey with the local SSH private-key path. Never put key contents in this command."
        }
    }

    $RequestedKey = [Environment]::ExpandEnvironmentVariables($RequestedKey.Trim())
    if ($RequestedKey.EndsWith(".pub", [StringComparison]::OrdinalIgnoreCase)) {
        $privateKey = $RequestedKey.Substring(0, $RequestedKey.Length - 4)
        $publicKey = $RequestedKey
    } else {
        $privateKey = $RequestedKey
        $publicKey = "$RequestedKey.pub"
    }

    if (-not (Test-Path -LiteralPath $privateKey -PathType Leaf)) {
        throw "SSH private key is not available at the configured path: $privateKey"
    }
    if (-not (Test-Path -LiteralPath $publicKey -PathType Leaf)) {
        throw "Matching SSH public key is not available: $publicKey"
    }

    return @{
        Private = [IO.Path]::GetFullPath($privateKey)
        Public = [IO.Path]::GetFullPath($publicKey)
    }
}

function Get-SignatureFile {
    param(
        [string]$KeyPath,
        [string]$InputPath
    )

    $sshKeygen = Get-SshKeygen
    & $sshKeygen -Y sign -n qosami-artifact -f $KeyPath $InputPath
    if ($LASTEXITCODE -ne 0) {
        throw "SSH signing failed. The artifact and manifest were retained; no signature is claimed."
    }

    $signaturePath = "$InputPath.sig"
    if (-not (Test-Path -LiteralPath $signaturePath -PathType Leaf)) {
        throw "ssh-keygen returned success but did not create $signaturePath"
    }
    return $signaturePath
}

function Get-RepositoryRelativePath {
    param([string]$Path)

    $fullPath = [IO.Path]::GetFullPath($Path)
    $rootPrefix = $repository.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) +
        [IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path must remain inside the repository: $Path"
    }
    return $fullPath.Substring($rootPrefix.Length).Replace([IO.Path]::DirectorySeparatorChar, "/")
}

switch ($Action) {
    "Install" {
        $keys = Get-SigningKeyPaths -RequestedKey $SigningKey
        $sshKeygen = Get-SshKeygen
        git -C $repository config core.hooksPath .githooks
        if ($LASTEXITCODE -ne 0) { throw "Could not configure the repository naming hook." }
        git -C $repository config gpg.format ssh
        if ($LASTEXITCODE -ne 0) { throw "Could not configure SSH commit signing." }
        git -C $repository config user.signingkey $keys.Public
        if ($LASTEXITCODE -ne 0) { throw "Could not configure the SSH public signing key." }
        git -C $repository config gpg.ssh.program $sshKeygen
        if ($LASTEXITCODE -ne 0) { throw "Could not configure ssh-keygen." }
        git -C $repository config commit.gpgsign true
        if ($LASTEXITCODE -ne 0) { throw "Could not enable signed commits." }
        Write-Output "Installed the staged-file naming hook and enabled SSH-signed Git commits."
        Write-Output "Private key remains at: $($keys.Private)"
    }

    "New" {
        if ([string]::IsNullOrWhiteSpace($Service) -or $Service -notmatch '^[A-Za-z0-9]{1,6}$') {
            throw "-Service must contain 1-6 letters or digits. QOSAMI plus the service name is at most 12 characters."
        }
        if ([string]::IsNullOrWhiteSpace($Extension) -or $Extension -notmatch '^\.[A-Za-z0-9]{1,10}$') {
            throw "-Extension must be a dot followed by 1-10 letters or digits, for example .rs or .md."
        }
        $hasInlineContent = $PSBoundParameters.ContainsKey("Content")
        $hasContentFile = $PSBoundParameters.ContainsKey("ContentFile")
        if ($hasInlineContent -eq $hasContentFile) {
            throw "Provide exactly one of -Content or -ContentFile."
        }
        if ($hasContentFile -and
            -not (Test-Path -LiteralPath $ContentFile -PathType Leaf)) {
            throw "Content file not found: $ContentFile"
        }
        if ([string]::IsNullOrWhiteSpace($Directory) -or [IO.Path]::IsPathRooted($Directory)) {
            throw "-Directory must be a repository-relative directory."
        }

        $serviceName = $Service.ToUpperInvariant()
        $stem = "QOSAMI$serviceName"
        if ($stem.Length -gt 12) { throw "Generated file stem exceeds the 12-character limit." }

        $keys = Get-SigningKeyPaths -RequestedKey $SigningKey
        $fingerprintOutput = & (Get-SshKeygen) -lf $keys.Public
        if ($LASTEXITCODE -ne 0) { throw "Could not read the public key fingerprint." }
        $fingerprint = (($fingerprintOutput -split '\s+')[1])

        $directoryPath = [IO.Path]::GetFullPath((Join-Path $repository $Directory))
        $rootPrefix = $repository.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) +
            [IO.Path]::DirectorySeparatorChar
        if (-not $directoryPath.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "-Directory must remain inside the repository."
        }
        if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) {
            New-Item -ItemType Directory -Path $directoryPath -Force | Out-Null
        }

        $artifactName = "$stem$($Extension.ToLowerInvariant())"
        $artifactPath = Join-Path $directoryPath $artifactName
        $manifestPath = "$artifactPath.sha256"
        if ((Test-Path -LiteralPath $artifactPath) -or (Test-Path -LiteralPath $manifestPath) -or
            (Test-Path -LiteralPath "$manifestPath.sig")) {
            throw "Artifact or signature sidecar already exists; refusing to overwrite it."
        }

        if ($hasContentFile) {
            $artifactContent = [IO.File]::ReadAllText([IO.Path]::GetFullPath($ContentFile))
        } else {
            $artifactContent = $Content
        }
        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($artifactPath, $artifactContent, $utf8)

        $relativePath = Get-RepositoryRelativePath -Path $artifactPath
        $pathBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($relativePath))
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifactPath).Hash.ToLowerInvariant()
        $manifestText = @(
            "format=QOSAMI-SHA256-SIGNATURE-V1"
            "artifact_path_utf8_base64=$pathBase64"
            "sha256=$hash"
            "signer_fingerprint=$fingerprint"
            "operator_statement=$statement"
            "statement_scope=user-provided; signature authenticates the signing key, not the statement's truth"
            "created_utc=$([DateTime]::UtcNow.ToString('o'))"
        ) -join "`n"
        [IO.File]::WriteAllText($manifestPath, "$manifestText`n", $utf8)
        $signaturePath = Get-SignatureFile -KeyPath $keys.Private -InputPath $manifestPath

        Write-Output "Created: $relativePath"
        Write-Output "SHA-256: $hash"
        Write-Output "Signed manifest: $(Get-RepositoryRelativePath -Path $manifestPath)"
        Write-Output "Detached signature: $(Get-RepositoryRelativePath -Path $signaturePath)"
        Write-Output "Commit separately with Git signing enabled; the signature does not establish ownership of other systems."
    }

    "Verify" {
        if ([string]::IsNullOrWhiteSpace($Manifest) -or
            -not (Test-Path -LiteralPath $Manifest -PathType Leaf)) {
            throw "Pass -Manifest with an existing .sha256 manifest."
        }
        if ([string]::IsNullOrWhiteSpace($AllowedSigners) -or
            -not (Test-Path -LiteralPath $AllowedSigners -PathType Leaf)) {
            throw "Pass -AllowedSigners with a trusted OpenSSH allowed-signers file."
        }
        if ([string]::IsNullOrWhiteSpace($SignerIdentity)) {
            throw "Pass -SignerIdentity with the identity expected in the trusted allowed-signers file."
        }

        $manifestPath = [IO.Path]::GetFullPath($Manifest)
        $manifestLines = [IO.File]::ReadAllLines($manifestPath)
        $hashLine = $manifestLines | Where-Object { $_ -match '^sha256=[0-9a-f]{64}$' } | Select-Object -First 1
        $pathLine = $manifestLines | Where-Object { $_ -match '^artifact_path_utf8_base64=' } | Select-Object -First 1
        if (-not $hashLine -or -not $pathLine -or $manifestLines[0] -ne "format=QOSAMI-SHA256-SIGNATURE-V1") {
            throw "Manifest format is invalid."
        }

        $relativePath = [Text.Encoding]::UTF8.GetString(
            [Convert]::FromBase64String($pathLine.Substring("artifact_path_utf8_base64=".Length))
        )
        $artifactPath = [IO.Path]::GetFullPath((Join-Path $repository $relativePath))
        $null = Get-RepositoryRelativePath -Path $artifactPath
        if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
            throw "Manifest artifact is missing: $relativePath"
        }
        $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifactPath).Hash.ToLowerInvariant()
        $expectedHash = $hashLine.Substring("sha256=".Length)
        if ($actualHash -ne $expectedHash) {
            throw "Artifact hash mismatch: expected $expectedHash, got $actualHash."
        }

        $signaturePath = "$manifestPath.sig"
        if (-not (Test-Path -LiteralPath $signaturePath -PathType Leaf)) {
            throw "Detached signature is missing: $signaturePath"
        }
        $sshKeygen = Get-SshKeygen
        $manifestText = [IO.File]::ReadAllText($manifestPath, [Text.Encoding]::UTF8)
        $verifyOutput = $manifestText | & $sshKeygen -Y verify -f ([IO.Path]::GetFullPath($AllowedSigners)) `
            -I $SignerIdentity -n qosami-artifact -s $signaturePath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "SSH signature verification failed: $($verifyOutput -join ' ')"
        }

        Write-Output "VERIFIED: SHA-256 matches and the trusted SSH signature is valid."
        Write-Output "artifact=$relativePath"
        Write-Output "sha256=$actualHash"
        Write-Output "signer_identity=$SignerIdentity"
    }
}
