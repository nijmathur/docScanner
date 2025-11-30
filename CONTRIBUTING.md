# Contributing to Secure Document Scanner

Thank you for your interest in contributing to the Secure Document Scanner project! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Development Workflow](#development-workflow)
- [GitHub Flow](#github-flow)
- [Branch Naming Convention](#branch-naming-convention)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [CI/CD Pipeline](#cicd-pipeline)
- [Security Guidelines](#security-guidelines)

## Code of Conduct

This project adheres to a code of conduct that all contributors are expected to follow:

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Maintain professional communication

## Development Workflow

We follow **GitHub Flow** for development:

```
main (protected)
  ↓
feature/your-feature (branch)
  ↓
Pull Request
  ↓
Code Review + CI/CD
  ↓
Merge to main
```

### Key Principles

1. **Main branch is always deployable** - Never commit directly to `main`
2. **Everything goes through Pull Requests** - No exceptions
3. **CI/CD must pass** - Build must succeed before merge
4. **Code review required** - At least one approval needed
5. **Tests are important** - Test failures are surfaced for visibility

## GitHub Flow

### 1. Create a Branch

Always create a new branch from the latest `main`:

```bash
# Update main
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/your-feature-name
```

### 2. Make Changes

- Write clean, maintainable code
- Follow Dart/Flutter best practices
- Add/update tests for your changes
- Update documentation as needed

### 3. Commit Changes

Use clear, descriptive commit messages:

```bash
git add .
git commit -m "feat: add biometric authentication support"
```

**Commit Message Format:**

```
<type>: <subject>

<optional body>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding/updating tests
- `chore`: Maintenance tasks

### 4. Push to GitHub

```bash
git push origin feature/your-feature-name
```

### 5. Create Pull Request

1. Go to GitHub repository
2. Click "New Pull Request"
3. Fill out the PR template completely
4. Link related issues
5. Request reviewers

### 6. Address Review Comments

- Respond to all review comments
- Make requested changes
- Push updates to the same branch
- Re-request review when ready

### 7. Merge

Once approved and CI passes:
- Use "Squash and merge" for clean history
- Delete the branch after merging

## Branch Naming Convention

Use descriptive branch names following this pattern:

```
<type>/<description>
```

### Examples:

- `feature/user-authentication`
- `fix/encryption-memory-leak`
- `docs/update-readme`
- `refactor/database-service`
- `test/add-backup-tests`
- `chore/update-dependencies`

### Branch Types:

- `feature/` - New features
- `fix/` - Bug fixes
- `hotfix/` - Critical production fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Test additions/updates
- `chore/` - Maintenance tasks

## Pull Request Process

### Before Creating PR

✅ **Checklist:**

1. [ ] Code compiles without errors
2. [ ] All tests pass locally
3. [ ] New tests added for new functionality
4. [ ] Code follows project style guidelines
5. [ ] Documentation updated
6. [ ] No sensitive data in code
7. [ ] Self-review completed

### PR Requirements

**Mandatory:**
- ✅ Build must pass (blocking)
- ✅ Code analysis must pass (blocking)
- ✅ At least one approval required
- ✅ All review comments addressed
- ⚠️ Tests should pass (non-blocking but visible)

**Recommended:**
- 📊 Coverage should not decrease
- 📝 Documentation updated
- 🔒 Security considerations addressed

### PR Review Process

1. **Automated Checks** (runs immediately)
   - Build verification
   - Code analysis
   - Test execution
   - Coverage generation
   - Security scan

2. **Code Review** (human reviewers)
   - Code quality
   - Architecture alignment
   - Security review
   - Performance considerations
   - Test adequacy

3. **Approval & Merge**
   - Minimum 1 approval
   - All CI checks pass
   - No unresolved comments
   - Branch up-to-date with main

## Coding Standards

### Dart Style Guide

Follow the official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style).

### Project-Specific Standards

1. **File Organization**
   ```
   lib/
   ├── core/
   │   ├── domain/entities/
   │   ├── services/
   │   └── data/
   └── features/
       └── <feature>/
           ├── screens/
           ├── widgets/
           └── providers/
   ```

2. **Naming Conventions**
   - Classes: `PascalCase`
   - Variables/Methods: `camelCase`
   - Constants: `lowerCamelCase`
   - Private members: `_leadingUnderscore`

3. **Code Style**
   - Use trailing commas for better diffs
   - Prefer `const` constructors
   - Use explicit types
   - Avoid abbreviations

4. **Documentation**
   - Document all public APIs
   - Use `///` for documentation comments
   - Include examples for complex functionality

### Example:

```dart
/// Encrypts data using AES-256-GCM encryption.
///
/// [plaintext] - The data to encrypt
/// [key] - 32-byte encryption key
///
/// Returns encrypted data with IV prepended.
///
/// Throws [ArgumentError] if key length is invalid.
Uint8List encryptBytes({
  required Uint8List plaintext,
  required Uint8List key,
}) {
  // Implementation
}
```

## Testing Requirements

### Test Coverage Goals

- **Core Services**: 100% coverage
- **Business Logic**: 90%+ coverage
- **UI Widgets**: 70%+ coverage
- **Overall**: 85%+ coverage

### Test Types

1. **Unit Tests** (required)
   - Test individual functions/classes
   - Mock external dependencies
   - Fast execution (<100ms per test)

2. **Widget Tests** (recommended)
   - Test UI components
   - Verify user interactions
   - Check visual state

3. **Integration Tests** (for complex features)
   - Test feature workflows
   - Verify system integration
   - Run on actual devices

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/core/services/encryption_service_test.dart

# Generate coverage
flutter test --coverage

# View coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Writing Tests

```dart
group('EncryptionService', () {
  late EncryptionService encryptionService;

  setUp(() {
    encryptionService = EncryptionService();
  });

  test('encrypts and decrypts data correctly', () {
    final plaintext = Uint8List.fromList('test'.codeUnits);
    final key = encryptionService.generateSalt();

    final encrypted = encryptionService.encryptBytes(
      plaintext: plaintext,
      key: key,
    );

    final decrypted = encryptionService.decryptBytes(
      ciphertext: encrypted,
      key: key,
    );

    expect(decrypted, equals(plaintext));
  });
});
```

## CI/CD Pipeline

### Pipeline Stages

Our CI/CD pipeline runs automatically on every PR:

#### 1. **Build** (blocking ❌ fails = no merge)
- Flutter setup
- Dependency installation
- Code analysis
- Format checking
- Android APK build
- iOS build (dry run)

#### 2. **Test** (non-blocking ⚠️ failures surfaced)
- Mock generation
- Unit test execution
- Coverage report generation
- Test results posted as PR comment

#### 3. **Quality** (informational ℹ️)
- TODO/FIXME detection
- Lines of code count
- Code complexity analysis

#### 4. **Security** (informational ℹ️)
- Dependency vulnerability scan
- Secret detection
- Security best practices check

### Pipeline Configuration

See [`.github/workflows/ci.yml`](.github/workflows/ci.yml) for full configuration.

### Viewing Results

1. **GitHub Actions Tab** - View all pipeline runs
2. **PR Checks** - See status directly on PR
3. **PR Comments** - Automated test results comment
4. **Artifacts** - Download coverage reports and logs

### Local Pipeline Simulation

Run the same checks locally before pushing:

```bash
# Install dependencies
flutter pub get

# Generate mocks
flutter pub run build_runner build --delete-conflicting-outputs

# Analyze
flutter analyze

# Format
dart format --set-exit-if-changed .

# Test
flutter test --coverage

# Build
flutter build apk --debug
```

## Security Guidelines

### Security-Critical Code

When working on security features:

1. **Encryption**
   - Use approved algorithms only (AES-256-GCM)
   - Never hardcode keys
   - Proper IV/nonce generation
   - Secure key derivation (PBKDF2 100k iterations)

2. **Authentication**
   - Validate all inputs
   - Secure session management
   - Proper timeout handling
   - Failed attempt tracking

3. **Data Storage**
   - Always encrypt sensitive data
   - Use SQLCipher for database
   - Secure file permissions
   - Audit logging

### Security Review Checklist

- [ ] No hardcoded credentials
- [ ] No sensitive data in logs
- [ ] Input validation implemented
- [ ] Encryption used where needed
- [ ] Secure random number generation
- [ ] SQL injection prevention
- [ ] XSS prevention (if web views used)

### Reporting Security Issues

**DO NOT** open public issues for security vulnerabilities.

Instead:
1. Email security concerns privately
2. Provide detailed reproduction steps
3. Allow time for patch before disclosure

## Getting Help

- 📖 Check existing documentation
- 🔍 Search closed issues/PRs
- 💬 Ask in discussions
- 📧 Contact maintainers

## License

By contributing, you agree that your contributions will be licensed under the project's license.

---

**Happy Contributing!** 🎉

Thank you for helping make Secure Document Scanner better!
