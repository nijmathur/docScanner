# GitHub Flow & CI/CD Guide

## Overview

This repository follows **GitHub Flow** with a comprehensive CI/CD pipeline to ensure code quality and stability before merging to `main`.

## Repository Configuration

### Branch Protection Rules ✅

The `main` branch is protected with the following rules:

- ✅ **Required status checks**: Build and CI Pipeline must pass
- ✅ **Pull Request reviews required**: Minimum 1 approval
- ✅ **Dismiss stale reviews**: Enabled
- ✅ **Strict status checks**: Branch must be up-to-date before merge
- ✅ **No force pushes**: Prevented
- ✅ **No deletions**: Prevented

### CI/CD Pipeline

The pipeline runs automatically on every PR and includes 4 jobs:

#### 1. **Build** (Required ❌ Blocks merge if fails)
- Flutter setup and dependency installation
- Code analysis with `flutter analyze`
- Code formatting check
- Android APK build
- iOS build (dry run)

**Status**: Must pass for PR to be mergeable

#### 2. **Test** (Non-blocking ⚠️ Failures surfaced)
- Mock generation with `build_runner`
- Unit test execution
- Coverage report generation
- Test results comment on PR
- Artifacts: coverage reports and test output

**Status**: Failures reported but don't block merge

#### 3. **Quality** (Informational ℹ️)
- TODO/FIXME detection
- Lines of code count
- Code complexity analysis

**Status**: Informational only

#### 4. **Security** (Informational ℹ️)
- Dependency vulnerability check
- Secret scanning
- Security best practices verification

**Status**: Informational only

## Development Workflow

### 1. Start a New Feature

```bash
# Ensure you're on main and up-to-date
git checkout main
git pull origin main

# Create a new feature branch
git checkout -b feature/your-feature-name
```

### 2. Make Changes

Write your code following the project's coding standards:
- Follow Dart style guide
- Add tests for new functionality
- Update documentation as needed
- Keep commits atomic and descriptive

### 3. Commit Changes

```bash
# Stage your changes
git add .

# Commit with a descriptive message
git commit -m "feat: add biometric authentication support"
```

**Commit Message Format**:
```
<type>: <subject>

<optional body>
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

### 4. Push to GitHub

```bash
git push origin feature/your-feature-name
```

### 5. Create Pull Request

1. Navigate to the repository on GitHub
2. Click "Pull requests" → "New pull request"
3. Select your feature branch
4. Fill out the PR template:
   - Description of changes
   - Type of change
   - Related issues
   - Testing done
   - Checklist items

### 6. Automated Checks Run

Once you create the PR, the CI/CD pipeline automatically runs:

```
┌─────────────────────────┐
│   PR Created/Updated    │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Build Job (Required)   │ ◄── Must pass
├─────────────────────────┤
│ - Setup Flutter         │
│ - Install dependencies  │
│ - Code analysis         │
│ - Format check          │
│ - Build Android APK     │
│ - Build iOS (dry run)   │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Test Job (Info only)   │ ◄── Failures reported
├─────────────────────────┤
│ - Generate mocks        │
│ - Run unit tests        │
│ - Generate coverage     │
│ - Comment results on PR │
└───────────┬─────────────┘
            │
            ├──► Quality Job
            │
            └──► Security Job
            │
            ▼
┌─────────────────────────┐
│  CI Success Check       │ ◄── Blocks merge
└─────────────────────────┘
```

### 7. Review Test Results

After the pipeline runs, check:

1. **Status checks** on the PR page
2. **Automated comment** with test results
3. **Artifacts** for detailed reports

Example automated comment:
```markdown
## 🧪 Test Results

**Status**: ✅ Tests Passed

**Summary**:
- ✅ Passing: 175 tests
- ❌ Failing: 0 tests
- 📊 Coverage: 87.5%

**Artifacts**:
- 📁 Download Coverage Report
- 📄 Download Test Output
```

### 8. Request Review

1. Assign reviewers
2. Wait for at least 1 approval
3. Address any review comments

### 9. Keep Branch Updated

If `main` is updated while your PR is open:

```bash
git checkout feature/your-feature-name
git fetch origin
git merge origin/main

# Or use rebase for cleaner history
git rebase origin/main

# Push the updates
git push origin feature/your-feature-name --force-with-lease
```

### 10. Merge the PR

Once all checks pass and you have approval:

1. Click "Squash and merge"
2. Edit the commit message if needed
3. Confirm the merge
4. Delete the feature branch

## CI/CD Pipeline Details

### Build Job Configuration

```yaml
- Flutter 3.22.1
- Ubuntu latest
- 15 minute timeout
- Required for merge
```

**Checks performed**:
- `flutter doctor -v`
- `flutter pub get`
- `flutter analyze --fatal-infos --fatal-warnings`
- `dart format --set-exit-if-changed .`
- `flutter build apk --debug --no-shrink`

### Test Job Configuration

```yaml
- Flutter 3.22.1
- Ubuntu latest
- 20 minute timeout
- Non-blocking
```

**Checks performed**:
- `flutter pub run build_runner build`
- `flutter test --coverage`
- Coverage report generation
- Automated PR comment

### Viewing Pipeline Logs

1. Go to the "Actions" tab on GitHub
2. Click on the workflow run
3. Select a job to see detailed logs
4. Download artifacts (coverage, test output)

## Handling CI Failures

### Build Failures (Blocks merge)

If build fails:

1. Check the error in GitHub Actions logs
2. Fix the issue locally:
   ```bash
   flutter analyze
   dart format .
   flutter build apk --debug
   ```
3. Commit and push the fix
4. Pipeline runs automatically

Common build failures:
- **Analyze errors**: Fix code issues
- **Format errors**: Run `dart format .`
- **Build errors**: Check dependencies, fix compile errors

### Test Failures (Non-blocking)

If tests fail:

1. Review the test output in the PR comment
2. Download the test artifacts for details
3. Fix failing tests locally:
   ```bash
   flutter test
   ```
4. Commit and push

**Note**: Test failures are currently non-blocking but should be fixed before merging.

## Best Practices

### Before Creating PR

✅ Run locally:
```bash
# Ensure everything works
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter analyze
dart format .
flutter test
flutter build apk --debug
```

### During Review

- ✅ Respond to all comments
- ✅ Keep commits focused
- ✅ Update branch with main regularly
- ✅ Re-request review after changes

### After Merge

- ✅ Delete the feature branch
- ✅ Pull latest main locally
- ✅ Verify deployment (if applicable)

## Common Workflows

### Hotfix Workflow

For urgent production fixes:

```bash
# Create hotfix branch
git checkout -b hotfix/critical-bug-fix main

# Make the fix
# ... edit files ...

# Commit and push
git commit -m "fix: resolve critical security vulnerability"
git push origin hotfix/critical-bug-fix

# Create PR with "hotfix" label
# Get fast-tracked review
# Merge to main
```

### Feature Branch Workflow

For new features:

```bash
# Create feature branch
git checkout -b feature/user-profile main

# Develop feature with multiple commits
git commit -m "feat: add user profile model"
git commit -m "feat: add profile edit screen"
git commit -m "test: add profile tests"

# Push and create PR
git push origin feature/user-profile
```

### Dependency Update Workflow

For updating dependencies:

```bash
# Create dependency update branch
git checkout -b chore/update-dependencies main

# Update pubspec.yaml
flutter pub upgrade

# Run tests
flutter test

# Commit and push
git commit -m "chore: update dependencies to latest versions"
git push origin chore/update-dependencies
```

## Troubleshooting

### Pipeline Not Running

**Issue**: CI pipeline doesn't start

**Solutions**:
- Check if branch is pushed to GitHub
- Verify `.github/workflows/ci.yml` exists
- Check GitHub Actions tab for errors
- Ensure repository has Actions enabled

### Status Check Not Required

**Issue**: Can merge without CI passing

**Solutions**:
- Verify branch protection rules
- Check required status check names match:
  - "Build Application"
  - "CI Pipeline Success"
- Re-apply branch protection if needed

### Permission Issues

**Issue**: Cannot push to branch or create PR

**Solutions**:
- Ensure you have write access to repository
- Check if main branch is protected (should be)
- Create feature branch and PR instead

## Additional Resources

- [CONTRIBUTING.md](../CONTRIBUTING.md) - Full contributing guidelines
- [GitHub Flow Documentation](https://docs.github.com/en/get-started/quickstart/github-flow)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Branch Protection Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches)

## Repository Links

- **Repository**: https://github.com/nijmathur/docScanner
- **Actions**: https://github.com/nijmathur/docScanner/actions
- **Pull Requests**: https://github.com/nijmathur/docScanner/pulls
- **Issues**: https://github.com/nijmathur/docScanner/issues

## Support

If you encounter issues with the CI/CD pipeline:

1. Check the troubleshooting section above
2. Review GitHub Actions logs
3. Search existing issues
4. Create a new issue with:
   - Pipeline run link
   - Error message
   - Steps to reproduce

---

**Last Updated**: 2025-11-29
**Pipeline Version**: 1.0
**Flutter Version**: 3.22.1
