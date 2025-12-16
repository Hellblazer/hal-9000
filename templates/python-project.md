# CLAUDE.md - Python Project Template

## Project

**Name**: [PROJECT_NAME]
**Description**: [DESCRIPTION]
**Python**: [VERSION]
**Manager**: [pip/poetry/uv]
**Framework**: [Django/Flask/FastAPI/None]

## Commands

```bash
source venv/bin/activate          # Activate venv
pip install -r requirements.txt   # Install (pip)
poetry install                    # Install (poetry)

python main.py                    # Run
pytest                            # Tests
pytest tests/test_x.py::test_fn   # Single test
pytest --cov=src tests/           # Coverage

ruff check src/                   # Lint
ruff format src/                  # Format
mypy src/                         # Type check
```

## Structure

```
src/            # Source
tests/          # Tests
requirements.txt / pyproject.toml
```

## Conventions

- Type hints on all functions
- Dataclasses for data structures
- Context managers (`with`)
- PEP 8, 88 char lines (Black)

## Testing

- Files: `test_*.py`
- Functions: `test_*`
- Use fixtures for setup
- Mock external dependencies

## Key Modules

- [MODULE] - [PURPOSE]

## Notes

[PROJECT-SPECIFIC GUIDANCE]
