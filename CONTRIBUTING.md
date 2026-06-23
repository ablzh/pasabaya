# Contributing to Pasabaya.app

First of all, thank you for taking the time to contribute to Pasabaya.app! Your help is highly appreciated, and together we can make carpooling and ride-sharing simple and accessible.

As a project built on **The One Person Framework** philosophy, I aim to keep the codebase clean, lean, and simple. I prefer leveraging native Rails features and avoiding unnecessary external dependencies.

---

## 🛠️ Getting Started

Before you start writing code, make sure you have followed the setup instructions in the [README.md](file:///Users/uzver/Repos/pasabaya/README.md)

---

## 🌿 Branching Policy

1. Fork the repository and create your branch from `main`.
2. Keep your branch names descriptive (e.g., `feature/add-profile-avatars` or `fix/ride-post-validation`).

---

## 🧪 Quality Standards

To maintain a healthy codebase, I ask all contributors to run tests and linters locally before submitting a Pull Request.

### 1. Code Style (RuboCop)
The project uses Rails' default Omakase style guide (`rubocop-rails-omakase`).
Check your code style by running:
```bash
bundle exec rubocop
```
Please resolve any style offenses before submitting your code.

### 2. Testing
Ensure your changes do not break existing features. The test suite includes unit, integration, and system tests.
- Run all tests:
  ```bash
  bin/rails test
  ```
- Run system tests (which run in a headless browser to test interactive features):
  ```bash
  bin/rails test:system
  ```

---

## 📬 Submitting a Pull Request

When you are ready to submit your changes:

1. Double-check that all tests pass and there are no RuboCop style offenses.
2. Push your branch to your fork.
3. Open a Pull Request against the `main` branch of `ablzh/pasabaya`.
4. Provide a clear description of the problem you are solving, what changes you made, and how to test them.
5. Wait for review! I will do my best to review your PR as soon as possible.

## 👀 If you find an error or have a suggestion
If you know how to resolve this yourself, the information above will help. 
If not, just open an issue and describe the situation in detail :)

Thank you again for contributing!