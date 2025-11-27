# Claude AI Assistant Guidelines

This document provides guidelines for AI assistants (particularly Claude) when working on the coreprotect-ruby project.

## Project Overview

**coreprotect-ruby** is a Ruby utility for purging old CoreProtect data in production environments.

- **Language**: Ruby
- **Purpose**: Database cleanup utility for Minecraft CoreProtect plugin data
- **Status**: In development - use with caution

## Critical Prerequisites

### 1. ALWAYS Verify CONTRIBUTING.md First

Before ANY work:
```bash
# Check if CONTRIBUTING.md is up-to-date
curl -s https://denpaio.github.io/CONTRIBUTING.md | diff CONTRIBUTING.md -

# If outdated, update it first
curl -o CONTRIBUTING.md https://denpaio.github.io/CONTRIBUTING.md
```

**Source of Truth**: https://denpaio.github.io/CONTRIBUTING.md

### 2. Follow Contribution Standards

All standards in `CONTRIBUTING.md` are MANDATORY:
- ✅ Code comments in English (or follow existing context)
- ✅ Follow Rubocop conventions (`.rubocop.yml`)
- ✅ Use Conventional Commits format
- ✅ Run linters before committing
- ✅ Ensure all tests pass

## Development Workflow

### Before Making Changes

1. **Verify CONTRIBUTING.md** is current (see above)
2. **Read relevant code** - Never propose changes to unread code
3. **Check existing conventions** in the codebase
4. **Run linters** to understand current state

### During Development

```bash
# Run Rubocop with auto-fix
rubocop -A

# Run tests (if available)
bundle exec rake test
# or
bundle exec rspec
```

### Before Committing

1. **Lint the code**:
   ```bash
   rubocop -A
   ```

2. **Verify tests pass**

3. **Use Conventional Commit format**:
   ```
   type(scope): description

   Examples:
   feat(purge): add support for filtering by action type
   fix(database): resolve connection timeout issue
   docs(readme): update installation instructions
   refactor(cli): simplify argument parsing
   ```

### Commit Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

## Project-Specific Guidelines

### Ruby Standards
- Follow Rubocop rules defined in `.rubocop.yml`
- Prefer self-documenting code over comments
- Use Ruby idioms and best practices

### Database Operations
- Be extremely careful with purge operations
- Always validate timestamps and filters
- Consider data safety in all changes

### CLI Interface
- Maintain consistency with existing Thor command structure
- Provide clear help messages
- Validate user input thoroughly

## Code Review Checklist

Before marking work complete:
- [ ] CONTRIBUTING.md is up-to-date
- [ ] All changes follow Rubocop conventions
- [ ] Tests pass (if applicable)
- [ ] Commit messages follow Conventional Commits
- [ ] Code is self-documenting
- [ ] No security vulnerabilities introduced
- [ ] Database operations are safe and validated

## Resources

- **CONTRIBUTING.md**: Project contribution guidelines (MUST be current)
- **README.md**: Project documentation and usage examples
- **Conventional Commits**: https://www.conventionalcommits.org/
- **Rubocop**: https://rubocop.org/

---

**Remember**: Quality over speed. Always verify standards compliance before completing any task.
