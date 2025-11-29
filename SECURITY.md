# Security Architecture

## Executive Summary

This document outlines the comprehensive security architecture of the Secure Document Scanner application. The app implements defense-in-depth security with multiple layers of protection:

- **Encryption at Rest**: AES-256-GCM for all documents and SQLCipher for database
- **Encryption in Transit**: TLS 1.3 for all cloud communications
- **Authentication**: Multi-factor (PIN + Biometric)
- **Key Management**: OS-level secure storage with PBKDF2 key derivation
- **Audit Logging**: Complete audit trail of all sensitive operations
- **Zero-Knowledge Architecture**: Cloud providers cannot access document contents

## Threat Model

### Assets

1. **Document Images**: Scanned documents containing sensitive information
2. **OCR Text**: Extracted text from documents
3. **Metadata**: Document titles, tags, and user-added information
4. **Encryption Keys**: Master key, DEK, BEK
5. **Authentication Credentials**: PIN, biometric templates
6. **Audit Logs**: Record of all system activities

### Threat Actors

1. **Physical Attacker**: Has physical access to unlocked device
2. **Malware**: Malicious app running on same device
3. **Network Attacker**: Can intercept network traffic
4. **Cloud Provider**: Has access to backup storage
5. **Forensic Analyst**: Has access to device storage dump

### Threats & Mitigations

| Threat | Impact | Likelihood | Mitigation |
|--------|--------|------------|------------|
| Unauthorized device access | High | Medium | PIN/Biometric auth, session timeout |
| Document theft from storage | High | Low | AES-256-GCM encryption, OS keychain |
| Backup interception | High | Low | End-to-end encryption with user password |
| Key extraction | High | Low | OS secure storage, PBKDF2 with 100k iterations |
| Malware data theft | High | Medium | App sandboxing, encrypted storage |
| Brute force PIN | Medium | Medium | 5 attempt lockout, biometric fallback |
| Network eavesdropping | High | Low | TLS 1.3, no plaintext transmission |
| Database compromise | High | Low | SQLCipher encryption |

## Cryptographic Implementation

### Algorithms & Parameters

#### Symmetric Encryption
- **Algorithm**: AES-256-GCM
- **Key Size**: 256 bits (32 bytes)
- **IV Size**: 128 bits (16 bytes)
- **Authentication Tag**: 128 bits (16 bytes)
- **Mode**: Galois/Counter Mode (provides both confidentiality and authenticity)

**Why AES-256-GCM?**
- Industry standard, FIPS 140-2 approved
- Authenticated encryption (prevents tampering)
- Parallel processing capability
- Resistant to known attacks

#### Key Derivation Function (KDF)
- **Algorithm**: PBKDF2-HMAC-SHA256
- **Iterations**: 100,000 (configurable)
- **Salt Size**: 256 bits (32 bytes)
- **Output Length**: 256 bits (32 bytes)

**Why PBKDF2 with 100k iterations?**
- NIST recommended
- Computationally expensive (slows brute force)
- Well-tested and widely supported
- 100k iterations = ~100ms on modern hardware

#### Hash Function
- **Algorithm**: SHA-256
- **Output Length**: 256 bits (32 bytes)
- **Usage**: Checksums, integrity verification, HMAC

#### Key Expansion
- **Algorithm**: HKDF-SHA256
- **Purpose**: Derive multiple keys from master key
- **Context Separation**: Different contexts for DEK, database key, etc.

### Key Hierarchy

```
User PIN/Biometric
        ↓
    (PBKDF2, 100k iterations, random salt)
        ↓
    Master Key (256 bits)
        ↓ (stored in OS Keychain/Keystore)
        ├─→ (HKDF) → Data Encryption Key (DEK)
        ├─→ (HKDF) → Database Encryption Key
        └─→ (HKDF) → Audit Log Key

Backup Password (user-provided, separate)
        ↓
    (PBKDF2, 100k iterations, random salt)
        ↓
    Backup Encryption Key (BEK) (256 bits)
        ↓
    Encrypted Backup Archive
```

### Encryption Process Details

#### Document Encryption

1. **Generate Random IV** (16 bytes using SecureRandom)
2. **Encrypt Image Data**
   ```
   Ciphertext = AES-256-GCM(
     key: DEK,
     iv: random_iv,
     plaintext: image_bytes,
     additional_data: document_id
   )
   ```
3. **Output Format**: `[IV][Ciphertext][Auth Tag]`
4. **Store**: Save to app-private storage

#### Database Encryption (SQLCipher)

```sql
-- On database creation
PRAGMA key = "derived_database_key";
PRAGMA cipher_page_size = 4096;
PRAGMA kdf_iter = 256000;
PRAGMA cipher_hmac_algorithm = HMAC_SHA512;
PRAGMA cipher_kdf_algorithm = PBKDF2_HMAC_SHA512;
```

#### Backup Encryption

1. **Create Archive**: tar.gz of database + encrypted files
2. **Derive BEK**: PBKDF2(backup_password, random_salt)
3. **Encrypt Archive**: AES-256-GCM(BEK, archive)
4. **Output Format**: `[Salt][IV][Encrypted Archive][Auth Tag]`
5. **Compute Checksum**: SHA-256 of entire encrypted backup

### Random Number Generation

- **Source**: Platform-specific CSPRNG
  - iOS: SecRandomCopyBytes
  - Android: SecureRandom (backed by /dev/urandom)
- **Usage**: IVs, salts, key generation
- **Quality**: Cryptographically secure

## Authentication & Access Control

### Authentication Methods

#### 1. PIN Authentication
- **Length**: 6 digits (enforced)
- **Validation**: Constant-time comparison
- **Storage**: Only salted hash stored (PBKDF2)
- **Failed Attempts**: Max 5, then lockout
- **Lockout Duration**: Permanent until device reset or biometric success

#### 2. Biometric Authentication
- **Types Supported**:
  - Face ID (iOS)
  - Touch ID (iOS)
  - Fingerprint (Android)
  - Face Unlock (Android, if hardware supports)
- **Storage**: Templates stored in Secure Enclave (iOS) or TEE (Android)
- **Fallback**: PIN required after 5 failed biometric attempts
- **Liveness Detection**: Platform-provided

#### 3. Session Management
- **Session Token**: In-memory only, never persisted
- **Timeout**: Configurable (default: 15 minutes)
- **App Background**: Immediate lock after timeout
- **App Termination**: Full re-authentication required

### Authorization Model

```
User
  ├─ View Documents (after authentication)
  ├─ Create Documents (after authentication)
  ├─ Update Documents (after authentication)
  ├─ Delete Documents (after authentication)
  ├─ Search Documents (after authentication)
  ├─ Create Backup (after authentication + backup password)
  └─ Restore Backup (after authentication + backup password)
```

- **Principle of Least Privilege**: App only requests necessary permissions
- **Permissions**:
  - Camera (for document capture)
  - Photo Library (for importing documents)
  - Biometric (for authentication)
  - Internet (for cloud backup only)

## Secure Storage

### iOS Keychain
```swift
// Keychain attributes
kSecAttrAccessible = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
kSecAttrSynchronizable = false
kSecUseAuthenticationContext = true (for biometric)
```

**Protection**:
- Hardware-backed encryption (Secure Enclave)
- Data only accessible when device unlocked
- Not included in iCloud backup
- Protected by device passcode + biometric

### Android Keystore
```kotlin
// Keystore parameters
setEncryptionPaddings(ENCRYPTION_PADDING_RSA_OAEP)
setUserAuthenticationRequired(true)
setUserAuthenticationValidityDurationSeconds(300)
setUnlockedDeviceRequired(true)
```

**Protection**:
- Hardware-backed encryption (TEE/StrongBox)
- Requires user authentication
- Not extractable
- Protected by device lock screen

### File System Storage
- **Location**: App-private directory
- **Permissions**: Owner read/write only (0600)
- **Encryption**: All documents encrypted with DEK
- **Database**: SQLCipher encrypted
- **Temporary Files**: Securely wiped after use

## Network Security

### TLS Configuration
- **Minimum Version**: TLS 1.3
- **Cipher Suites**: Modern, secure suites only
  - TLS_AES_256_GCM_SHA384
  - TLS_CHACHA20_POLY1305_SHA256
- **Certificate Validation**: Full chain validation, no self-signed
- **Certificate Pinning**: Recommended for production

### Cloud Provider Authentication
- **Method**: OAuth 2.0
- **Token Storage**: Encrypted in secure storage
- **Token Refresh**: Automatic
- **Token Revocation**: On sign-out

### Data in Transit
- **Backup Upload**: Encrypted before upload (BEK)
- **Cloud Provider**: Cannot decrypt backup contents
- **MITM Protection**: TLS 1.3 + certificate validation

## Audit & Logging

### Logged Events

1. **Authentication Events**
   - Successful login (method, timestamp)
   - Failed login attempts (reason, timestamp)
   - Session timeout
   - Biometric fallback

2. **Document Operations**
   - Document created (ID, type, size)
   - Document viewed (ID, timestamp)
   - Document updated (ID, changes)
   - Document deleted (ID, timestamp)

3. **Search Operations**
   - Query executed (query text, result count)
   - Filters applied

4. **Backup/Restore**
   - Backup created (provider, size, document count)
   - Backup uploaded (provider, timestamp)
   - Backup downloaded (provider, timestamp)
   - Restore completed (document count)

5. **Security Events**
   - Decryption errors (document ID, error type)
   - Key access (key type, operation)
   - Failed authentication (attempts count)

### Audit Log Security
- **Storage**: SQLCipher encrypted database
- **Integrity**: Append-only, no deletions
- **Tampering Detection**: Checksums for each entry
- **Retention**: Indefinite (user can export/clear)
- **Export**: JSON format with integrity signature

### What is NOT Logged
- Actual document contents
- OCR text (only length)
- User PIN
- Encryption keys
- Backup passwords

## Security Best Practices

### For Users

1. **Use Strong PIN**
   - Avoid 000000, 123456, birthdays
   - Change periodically
   - Don't share with others

2. **Enable Biometric**
   - Faster access
   - More secure than PIN alone
   - Fallback to PIN available

3. **Use Different Backup Password**
   - Never reuse your PIN
   - Use strong password (12+ chars)
   - Store securely (password manager)

4. **Regular Backups**
   - Backup to multiple providers
   - Test restore periodically
   - Keep backup passwords secure

5. **Device Security**
   - Use strong device passcode
   - Enable automatic lock
   - Keep OS updated
   - Use device encryption

### For Developers

1. **Code Security**
   - No hardcoded secrets
   - Sanitize all inputs
   - Use parameterized queries
   - Handle errors securely

2. **Key Management**
   - Never log keys
   - Wipe keys from memory
   - Use OS secure storage
   - Rotate keys periodically

3. **Dependencies**
   - Keep packages updated
   - Audit dependencies
   - Use verified packages
   - Pin versions

4. **Testing**
   - Unit test crypto functions
   - Test auth flows
   - Fuzzing for inputs
   - Security code review

## Compliance

### Data Protection Regulations

#### GDPR Compliance
- ✅ Data minimization
- ✅ Encryption at rest and in transit
- ✅ Right to erasure (document deletion)
- ✅ Data portability (export feature)
- ✅ Privacy by design
- ✅ Audit logs for accountability
- ⚠️ Privacy policy required
- ⚠️ Data processing agreement for cloud

#### HIPAA Compliance (for healthcare use)
- ✅ Access controls (authentication)
- ✅ Encryption of PHI
- ✅ Audit trails
- ✅ Automatic logoff (session timeout)
- ⚠️ Business Associate Agreement needed for cloud
- ⚠️ Additional technical safeguards may be required
- ⚠️ Risk analysis documentation needed

#### PCI DSS (if storing payment card data)
- ⚠️ Additional requirements needed
- ⚠️ Do not use this app for credit card storage without proper assessment

### Security Certifications

**Recommended:**
- ISO 27001 (Information Security Management)
- SOC 2 Type II (if offering as service)
- FIPS 140-2 validation (for cryptographic modules)

## Vulnerability Disclosure

### Reporting Security Issues

**DO NOT** create public GitHub issues for security vulnerabilities.

**Instead:**
1. Email: security@[your-domain].com
2. Include:
   - Vulnerability description
   - Steps to reproduce
   - Impact assessment
   - Suggested fix (if any)
3. Allow 90 days for remediation before public disclosure

### Security Update Process

1. **Assessment** (1-3 days)
   - Validate vulnerability
   - Assess severity (CVSS score)
   - Determine impact

2. **Remediation** (7-30 days)
   - Develop fix
   - Test thoroughly
   - Prepare security advisory

3. **Release** (1-2 days)
   - Publish patched version
   - Notify users
   - Release advisory

## Security Roadmap

### Current Implementation (v1.0)
- ✅ AES-256-GCM encryption
- ✅ SQLCipher database
- ✅ PIN + Biometric auth
- ✅ Audit logging
- ✅ Encrypted backups

### Planned Enhancements (v1.1+)
- [ ] Hardware security module (HSM) support
- [ ] Certificate pinning
- [ ] Advanced key rotation
- [ ] Secure document sharing (encrypted links)
- [ ] Multi-user support with RBAC
- [ ] Security compliance reports

### Future Considerations
- [ ] Homomorphic encryption for cloud search
- [ ] Zero-knowledge proofs
- [ ] Blockchain for audit trail integrity
- [ ] Post-quantum cryptography migration

## Security Testing

### Regular Security Assessments

1. **Static Analysis**
   - Dart analyzer
   - Security linting rules
   - Dependency vulnerability scanning

2. **Dynamic Analysis**
   - Penetration testing
   - Fuzzing inputs
   - Runtime security checks

3. **Code Review**
   - Security-focused review
   - Cryptographic implementation review
   - Access control verification

### Recommended Tools
- **Static**: Snyk, OWASP Dependency-Check
- **Dynamic**: OWASP ZAP, Burp Suite
- **Mobile**: MobSF, Frida
- **Crypto**: Cryptofuzz, TestU01

## Incident Response Plan

### In Case of Security Breach

1. **Immediate Actions**
   - Isolate affected systems
   - Preserve evidence
   - Notify security team

2. **Investigation**
   - Determine scope of breach
   - Identify compromised data
   - Analyze attack vector

3. **Remediation**
   - Patch vulnerability
   - Rotate compromised keys
   - Update security measures

4. **Communication**
   - Notify affected users
   - Regulatory disclosure (if required)
   - Public advisory

5. **Post-Incident**
   - Root cause analysis
   - Update security measures
   - Improve monitoring

## References

- [OWASP Mobile Security Testing Guide](https://owasp.org/www-project-mobile-security-testing-guide/)
- [NIST Cryptographic Standards](https://csrc.nist.gov/publications)
- [Apple iOS Security Guide](https://support.apple.com/guide/security/)
- [Android Security Best Practices](https://developer.android.com/topic/security/best-practices)
- [RFC 5869 - HKDF](https://tools.ietf.org/html/rfc5869)
- [RFC 8018 - PBKDF2](https://tools.ietf.org/html/rfc8018)

---

**Last Updated**: 2025-11-29
**Version**: 1.0
**Classification**: Public
