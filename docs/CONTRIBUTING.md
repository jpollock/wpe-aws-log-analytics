# Contributing to Log Analytics

Thank you for your interest in contributing to the Log Analytics project! This document provides guidelines and instructions for contributing.

## Getting Started

### Prerequisites

- Node.js 18 or higher
- npm
- AWS CLI
- Terraform
- Git

### Development Environment Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd log-analytics
```

2. Install Lambda function dependencies:
```bash
cd infrastructure/terraform/lambda
npm install
```

3. Run tests:
```bash
npm test
```

## Development Workflow

### 1. Creating a New Feature

1. Create a new branch:
```bash
git checkout -b feature/your-feature-name
```

2. Make your changes
3. Add tests
4. Update documentation
5. Submit a pull request

### 2. Code Style

We follow these conventions:

- Use ES6+ features
- 2 spaces for indentation
- Semi-colons required
- Single quotes for strings
- Clear, descriptive variable names
- JSDoc comments for functions

Example:
```javascript
/**
 * Parses a log line and extracts relevant information
 * @param {string} line - The log line to parse
 * @returns {Object|null} Parsed log entry or null if invalid
 */
const parseLogLine = (line) => {
  // Implementation
};
```

### 3. Testing

All new features should include tests:

- Unit tests for new functions
- Integration tests for infrastructure changes
- Test both success and error cases
- Mock external services

Example test:
```javascript
describe('parseLogLine', () => {
  test('handles valid log line', () => {
    const result = parseLogLine('[2025-02-09] test message');
    expect(result).toEqual({
      timestamp: expect.any(String),
      message: 'test message'
    });
  });

  test('returns null for invalid line', () => {
    expect(parseLogLine('invalid')).toBeNull();
  });
});
```

### 4. Documentation

Update documentation when you:

- Add new features
- Change existing functionality
- Modify infrastructure
- Add new configuration options

Documentation locations:
- `/docs/user-guide/`: User documentation
- `/docs/technical/`: Technical documentation
- Code comments: Implementation details
- README.md: Project overview

## Infrastructure Changes

### 1. Terraform Guidelines

- Use variables for configurable values
- Add descriptions to all variables
- Use consistent naming conventions
- Test changes in a staging environment
- Document new variables in README

Example:
```hcl
variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}
```

### 2. AWS Resources

When adding new AWS resources:

1. Follow least privilege principle for IAM
2. Enable encryption by default
3. Add appropriate tags
4. Consider costs
5. Document cleanup procedures

## Pull Request Process

1. Update the README.md with details of changes
2. Update the version numbers following [SemVer](http://semver.org/)
3. Include relevant issue numbers in PR description
4. Ensure all tests pass
5. Update documentation
6. Request review from maintainers

### PR Checklist

- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] Version numbers updated
- [ ] Change log updated
- [ ] Infrastructure changes tested
- [ ] Code style guidelines followed
- [ ] Security considerations addressed

## Reporting Issues

### Bug Reports

Include:
1. Description of the bug
2. Steps to reproduce
3. Expected behavior
4. Actual behavior
5. Environment details
6. Relevant logs

### Feature Requests

Include:
1. Clear description of the feature
2. Use cases
3. Expected benefits
4. Implementation suggestions (optional)

## Code Review Process

All submissions require review:

1. Maintainers review code quality
2. CI/CD pipeline runs tests
3. Documentation is reviewed
4. Security implications considered
5. Performance impact evaluated

## Community

- Be respectful and inclusive
- Help others when possible
- Share knowledge
- Follow the code of conduct

## Questions?

- Open an issue for clarification
- Join our community chat (coming soon)
- Check existing documentation
- Contact maintainers

Thank you for contributing to Log Analytics!
