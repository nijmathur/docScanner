#!/bin/bash

# Test runner script for Secure Document Scanner
# Usage: ./run_tests.sh [options]
#
# Options:
#   --all       Run all tests (default)
#   --unit      Run only unit tests
#   --integration Run only integration tests
#   --coverage  Generate coverage report
#   --watch     Run in watch mode

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}======================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}======================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

# Parse arguments
TEST_TYPE="${1:---all}"

case $TEST_TYPE in
    --all)
        print_header "Running All Tests"

        print_info "Getting dependencies..."
        flutter pub get

        print_info "Generating mocks..."
        flutter pub run build_runner build --delete-conflicting-outputs

        print_info "Running unit tests..."
        flutter test --reporter expanded

        if [ $? -eq 0 ]; then
            print_success "All tests passed!"
        else
            print_error "Some tests failed"
            exit 1
        fi
        ;;

    --unit)
        print_header "Running Unit Tests"
        flutter pub run build_runner build --delete-conflicting-outputs
        flutter test test/ --reporter expanded
        ;;

    --integration)
        print_header "Running Integration Tests"
        flutter test integration_test/ --reporter expanded
        ;;

    --coverage)
        print_header "Running Tests with Coverage"

        print_info "Installing dependencies..."
        flutter pub get
        flutter pub run build_runner build --delete-conflicting-outputs

        print_info "Running tests with coverage..."
        flutter test --coverage

        if [ $? -eq 0 ]; then
            print_success "Tests passed! Generating coverage report..."

            # Check if lcov is installed
            if command -v lcov &> /dev/null; then
                genhtml coverage/lcov.info -o coverage/html
                print_success "Coverage report generated at coverage/html/index.html"

                # Open coverage report (macOS/Linux)
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    open coverage/html/index.html
                elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
                    xdg-open coverage/html/index.html
                fi
            else
                print_error "lcov not installed. Install with: brew install lcov (macOS) or sudo apt-get install lcov (Linux)"
            fi
        else
            print_error "Tests failed"
            exit 1
        fi
        ;;

    --watch)
        print_header "Running Tests in Watch Mode"
        flutter test --watch
        ;;

    *)
        echo "Usage: ./run_tests.sh [--all|--unit|--integration|--coverage|--watch]"
        exit 1
        ;;
esac

print_success "Done!"
