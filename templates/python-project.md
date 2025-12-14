# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**[Project Name]**: [Brief description]

[Add 2-3 sentences about what this project does and its purpose]

## Tech Stack

- **Python Version**: [3.10 / 3.11 / 3.12]
- **Dependency Manager**: [pip / poetry / pipenv]
- **Framework**: [Django / Flask / FastAPI / etc.]
- **Testing**: [pytest / unittest]

## Environment Setup

### Virtual Environment
```bash
# Create virtual environment
python3 -m venv venv

# Activate (macOS/Linux)
source venv/bin/activate

# Activate (Windows)
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
# Or with poetry:
poetry install
```

## Common Commands

```bash
# Run the application
python main.py
# Or with framework:
python manage.py runserver  # Django
flask run                    # Flask
uvicorn main:app --reload   # FastAPI

# Run tests
pytest
# Or:
python -m pytest

# Run specific test
pytest tests/test_module.py::test_function

# Run with coverage
pytest --cov=src tests/

# Lint code
flake8 src/
pylint src/
ruff check src/

# Format code
black src/
ruff format src/

# Type checking
mypy src/
```

## Project Structure

```
project-root/
├── src/                    # Source code
│   ├── __init__.py
│   ├── main.py
│   ├── models/             # Data models
│   ├── services/           # Business logic
│   └── utils/              # Utilities
├── tests/                  # Test files
├── requirements.txt        # Dependencies (pip)
├── pyproject.toml          # Project config (poetry)
└── README.md
```

### Key Modules

- `[module]` - [Purpose]
- `[module]` - [Purpose]

## Architecture

[Describe your architecture. Examples:]

### Layered Architecture
- Models: Data structures and database models
- Services: Business logic
- Controllers/Views: Request handlers
- Repositories: Data access layer

### [Your Architecture Pattern]
[Describe key architectural decisions]

## Python Best Practices

### Code Style
- Follow PEP 8
- Use type hints for function signatures
- Docstrings for all public functions/classes
- Max line length: 88 (Black default) or 79 (PEP 8)

### Type Hints
```python
from typing import List, Dict, Optional

def process_data(items: List[str], config: Optional[Dict[str, int]] = None) -> bool:
    """Process data with optional configuration."""
    pass
```

### Common Patterns
- Use context managers (`with` statements)
- Prefer list/dict comprehensions when readable
- Use dataclasses for simple data structures
- Handle exceptions explicitly

## Testing Strategy

### Test Structure
```python
def test_function_should_do_something_when_condition():
    # Arrange
    expected = "result"

    # Act
    actual = function_under_test()

    # Assert
    assert actual == expected
```

### Running Tests
```bash
# All tests
pytest

# Specific file
pytest tests/test_module.py

# Specific test
pytest tests/test_module.py::test_function

# With coverage report
pytest --cov=src --cov-report=html tests/

# Verbose output
pytest -v

# Stop on first failure
pytest -x
```

### Test Conventions
- Test files: `test_*.py` or `*_test.py`
- Test functions: Start with `test_`
- Use fixtures for shared setup
- Mock external dependencies

## Dependencies

### Managing Dependencies

With pip:
```bash
# Install
pip install package-name

# Freeze dependencies
pip freeze > requirements.txt

# Install from requirements
pip install -r requirements.txt
```

With poetry:
```bash
# Add dependency
poetry add package-name

# Add dev dependency
poetry add --group dev package-name

# Update dependencies
poetry update
```

## Database (if applicable)

### Migrations
```bash
# Django
python manage.py makemigrations
python manage.py migrate

# Alembic (SQLAlchemy)
alembic revision --autogenerate -m "description"
alembic upgrade head
```

### Connection
- Development: SQLite / PostgreSQL
- Production: PostgreSQL
- Configuration: [Environment variables / config file]

## Environment Variables

Create `.env` file:
```
DATABASE_URL=postgresql://user:pass@localhost/dbname
SECRET_KEY=your-secret-key
DEBUG=True
```

Load with:
```python
from dotenv import load_dotenv
import os

load_dotenv()
secret_key = os.getenv("SECRET_KEY")
```

## Common Development Tasks

### Adding a New Feature
1. Create branch
2. Implement functionality with type hints
3. Add/update tests
4. Run linter and formatter
5. Ensure tests pass
6. Update documentation

### API Development (if applicable)
- Endpoints: [Location/pattern]
- Request validation: [Pydantic / Marshmallow]
- Error responses: [Standard format]

## Code Quality Tools

### Linting
```bash
# flake8
flake8 src/

# pylint
pylint src/

# ruff (fast alternative)
ruff check src/
```

### Formatting
```bash
# black
black src/

# ruff format
ruff format src/
```

### Type Checking
```bash
# mypy
mypy src/
```

## Git Workflow

- Branch naming: `feature/description`, `fix/description`
- Commit messages: [Your convention]
- Pre-commit hooks: [If using pre-commit]

## Troubleshooting

### Import Errors
- Ensure virtual environment is activated
- Check `PYTHONPATH` if needed
- Verify package is installed: `pip list`

### Test Failures
- Check pytest output for details
- Run with `-v` for verbose output
- Use `pytest --pdb` to drop into debugger on failure

### Database Issues
- Check connection string
- Verify database is running
- Run migrations: `python manage.py migrate`

## Links & Resources

- [Documentation URL]
- [Issue Tracker URL]
- [API Documentation]
- [Deployment Guide]

## Notes for Claude Code

[Add any specific guidance for Claude when working in this codebase]

- [Framework-specific patterns]
- [Database interaction patterns]
- [Error handling conventions]
- [Specific considerations for this project]
