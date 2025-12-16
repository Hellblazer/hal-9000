#!/usr/bin/env python3
"""
Test script for security fixes in the DEVONthink MCP server.
Tests validation, timeouts, and error handling.

Run with: python3 -m pytest tests/test_security.py -v
Or standalone: python3 tests/test_security.py
"""

import sys
import asyncio
import tempfile
import os
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

import server


class TestBasicValidation:
    """Test basic input validation functions"""

    def test_query_empty_rejected(self):
        """Empty query should be rejected"""
        try:
            server.validate_query("")
            assert False, "Empty query should fail"
        except ValueError as e:
            assert "empty" in str(e).lower()

    def test_query_too_long_rejected(self):
        """Query over max length should be rejected"""
        try:
            server.validate_query("a" * 2000)
            assert False, "Long query should fail"
        except ValueError as e:
            assert "too long" in str(e).lower()

    def test_query_valid_accepted(self):
        """Valid query should be accepted"""
        result = server.validate_query("valid query")
        assert result == "valid query"

    def test_uuid_invalid_rejected(self):
        """Invalid UUID format should be rejected"""
        try:
            server.validate_uuid("invalid-uuid")
            assert False, "Invalid UUID should fail"
        except ValueError:
            pass

    def test_uuid_valid_accepted(self):
        """Valid UUID should be accepted"""
        result = server.validate_uuid("12345678-1234-1234-1234-123456789012")
        assert result == "12345678-1234-1234-1234-123456789012"

    def test_limit_zero_rejected(self):
        """Limit of 0 should be rejected"""
        try:
            server.validate_limit(0)
            assert False, "Limit 0 should fail"
        except ValueError:
            pass

    def test_limit_too_high_rejected(self):
        """Limit over max should be rejected"""
        try:
            server.validate_limit(200)
            assert False, "Limit 200 should fail"
        except ValueError:
            pass

    def test_limit_valid_accepted(self):
        """Valid limit should be accepted"""
        result = server.validate_limit(50)
        assert result == 50

    def test_content_empty_rejected(self):
        """Empty content should be rejected"""
        try:
            server.validate_content("")
            assert False, "Empty content should fail"
        except ValueError:
            pass

    def test_content_too_large_rejected(self):
        """Content over max size should be rejected"""
        try:
            large_content = "x" * (11 * 1024 * 1024)  # 11MB
            server.validate_content(large_content)
            assert False, "Large content should fail"
        except ValueError:
            pass

    def test_content_valid_accepted(self):
        """Valid content should be accepted"""
        result = server.validate_content("valid content")
        assert result == "valid content"

    def test_doc_type_invalid_rejected(self):
        """Invalid doc type should be rejected"""
        try:
            server.validate_doc_type("invalid")
            assert False, "Invalid doc type should fail"
        except ValueError:
            pass

    def test_doc_type_valid_accepted(self):
        """Valid doc type should be accepted"""
        result = server.validate_doc_type("markdown")
        assert result == "markdown"


class TestURLValidation:
    """Test URL validation (security critical)"""

    def test_url_empty_rejected(self):
        """Empty URL should be rejected"""
        try:
            server.validate_url("")
            assert False, "Empty URL should fail"
        except ValueError:
            pass

    def test_url_file_scheme_rejected(self):
        """file:// URLs should be rejected"""
        try:
            server.validate_url("file:///etc/passwd")
            assert False, "file:// URL should fail"
        except ValueError as e:
            assert "not allowed" in str(e).lower()

    def test_url_ftp_scheme_rejected(self):
        """ftp:// URLs should be rejected"""
        try:
            server.validate_url("ftp://example.com/file.pdf")
            assert False, "ftp:// URL should fail"
        except ValueError as e:
            assert "not allowed" in str(e).lower()

    def test_url_javascript_scheme_rejected(self):
        """javascript: URLs should be rejected"""
        try:
            server.validate_url("javascript:alert(1)")
            assert False, "javascript: URL should fail"
        except ValueError as e:
            assert "not allowed" in str(e).lower()

    def test_url_no_host_rejected(self):
        """URLs without host should be rejected"""
        try:
            server.validate_url("http:///path")
            assert False, "URL without host should fail"
        except ValueError as e:
            assert "host" in str(e).lower()

    def test_url_http_accepted(self):
        """http:// URLs should be accepted"""
        result = server.validate_url("http://example.com/file.pdf")
        assert result == "http://example.com/file.pdf"

    def test_url_https_accepted(self):
        """https:// URLs should be accepted"""
        result = server.validate_url("https://example.com/file.pdf")
        assert result == "https://example.com/file.pdf"


class TestFilePathValidation:
    """Test file path validation (security critical)"""

    def test_path_empty_rejected(self):
        """Empty path should be rejected"""
        try:
            server.validate_file_path("")
            assert False, "Empty path should fail"
        except ValueError:
            pass

    def test_path_nonexistent_rejected(self):
        """Non-existent path should be rejected"""
        try:
            server.validate_file_path("/nonexistent/path/file.txt")
            assert False, "Non-existent path should fail"
        except ValueError as e:
            assert "not found" in str(e).lower()

    def test_path_directory_rejected(self):
        """Directory path should be rejected"""
        try:
            server.validate_file_path("/tmp")
            assert False, "Directory path should fail"
        except ValueError as e:
            assert "not a regular file" in str(e).lower()

    def test_path_outside_allowed_rejected(self):
        """Path outside allowed directories should be rejected"""
        try:
            # /etc is outside home and temp directories
            server.validate_file_path("/etc/hosts")
            assert False, "Path outside allowed dirs should fail"
        except ValueError as e:
            assert "allowed directory" in str(e).lower()

    def test_path_ssh_rejected(self):
        """Paths containing .ssh should be rejected"""
        # Create a temp file to test with
        home = Path.home()
        ssh_dir = home / ".ssh"
        if ssh_dir.exists():
            # Find any file in .ssh to test
            for f in ssh_dir.iterdir():
                if f.is_file():
                    try:
                        server.validate_file_path(str(f))
                        assert False, ".ssh path should fail"
                    except ValueError as e:
                        assert "sensitive" in str(e).lower()
                    break

    def test_path_valid_temp_accepted(self):
        """Valid file in temp directory should be accepted"""
        # Create a temp file
        with tempfile.NamedTemporaryFile(delete=False, suffix=".txt") as f:
            f.write(b"test content")
            temp_path = f.name

        try:
            result = server.validate_file_path(temp_path)
            # Result is the resolved path, which may differ from input
            # (e.g., /var/folders -> /private/var/folders on macOS)
            assert Path(result).exists()
            assert Path(result).is_file()
        finally:
            os.unlink(temp_path)

    def test_path_valid_home_accepted(self):
        """Valid file in home directory should be accepted"""
        home = Path.home()
        # Create a test file in home directory
        test_file = home / ".devonthink_mcp_test_file.txt"
        try:
            test_file.write_text("test content")
            result = server.validate_file_path(str(test_file))
            assert Path(result).exists()
        finally:
            if test_file.exists():
                test_file.unlink()


class TestAcademicIdentifierValidation:
    """Test academic paper identifier validation"""

    def test_arxiv_invalid_rejected(self):
        """Invalid arXiv ID should be rejected"""
        invalid_ids = ["invalid", "12345", "2301.1", "abcd.12345"]
        for arxiv_id in invalid_ids:
            try:
                server.validate_arxiv_id(arxiv_id)
                assert False, f"Invalid arXiv ID {arxiv_id} should fail"
            except ValueError:
                pass

    def test_arxiv_valid_accepted(self):
        """Valid arXiv IDs should be accepted"""
        valid_ids = ["2301.00001", "2312.12345", "2301.00001v1", "2301.00001v12"]
        for arxiv_id in valid_ids:
            result = server.validate_arxiv_id(arxiv_id)
            assert result == arxiv_id

    def test_pubmed_invalid_rejected(self):
        """Invalid PubMed ID should be rejected"""
        invalid_ids = ["invalid", "12345", "PMC", "PMCABC"]
        for pubmed_id in invalid_ids:
            try:
                server.validate_pubmed_id(pubmed_id)
                assert False, f"Invalid PubMed ID {pubmed_id} should fail"
            except ValueError:
                pass

    def test_pubmed_valid_accepted(self):
        """Valid PubMed IDs should be accepted"""
        valid_ids = ["PMC12345", "PMC123456789", "pmc12345"]
        for pubmed_id in valid_ids:
            result = server.validate_pubmed_id(pubmed_id)
            assert result == pubmed_id

    def test_doi_invalid_rejected(self):
        """Invalid DOI should be rejected"""
        invalid_ids = ["invalid", "10.123", "11.1234/abc"]
        for doi in invalid_ids:
            try:
                server.validate_doi(doi)
                assert False, f"Invalid DOI {doi} should fail"
            except ValueError:
                pass

    def test_doi_valid_accepted(self):
        """Valid DOIs should be accepted"""
        valid_ids = ["10.1000/xyz123", "10.12345/abc.def.123", "10.1038/nature12373"]
        for doi in valid_ids:
            result = server.validate_doi(doi)
            assert result == doi


class TestScriptValidation:
    """Test script name validation"""

    def test_invalid_script_rejected(self):
        """Invalid script names should be rejected"""
        async def run_test():
            try:
                await server.run_applescript("malicious_script", "arg1")
                assert False, "Invalid script name should fail"
            except ValueError as e:
                assert "Invalid script name" in str(e)

        asyncio.run(run_test())


class TestSecurityConstants:
    """Test that security constants are defined"""

    def test_allowed_scripts_defined(self):
        """ALLOWED_SCRIPTS should be defined"""
        assert hasattr(server, 'ALLOWED_SCRIPTS')
        assert 'search' in server.ALLOWED_SCRIPTS
        assert 'read' in server.ALLOWED_SCRIPTS
        assert 'create' in server.ALLOWED_SCRIPTS
        assert 'import' in server.ALLOWED_SCRIPTS

    def test_allowed_doc_types_defined(self):
        """ALLOWED_DOC_TYPES should be defined"""
        assert hasattr(server, 'ALLOWED_DOC_TYPES')
        assert 'markdown' in server.ALLOWED_DOC_TYPES

    def test_allowed_url_schemes_defined(self):
        """ALLOWED_URL_SCHEMES should be defined"""
        assert hasattr(server, 'ALLOWED_URL_SCHEMES')
        assert 'http' in server.ALLOWED_URL_SCHEMES
        assert 'https' in server.ALLOWED_URL_SCHEMES
        assert 'file' not in server.ALLOWED_URL_SCHEMES

    def test_max_constants_defined(self):
        """Max limit constants should be defined"""
        assert hasattr(server, 'MAX_QUERY_LENGTH')
        assert hasattr(server, 'MAX_CONTENT_SIZE')
        assert hasattr(server, 'MAX_SEARCH_LIMIT')
        assert hasattr(server, 'MAX_IMPORT_FILE_SIZE')

    def test_patterns_defined(self):
        """Regex patterns should be defined"""
        assert hasattr(server, 'UUID_PATTERN')
        assert hasattr(server, 'ARXIV_PATTERN')
        assert hasattr(server, 'PUBMED_PATTERN')
        assert hasattr(server, 'DOI_PATTERN')


def run_standalone_tests():
    """Run tests in standalone mode (without pytest)"""
    print("=" * 60)
    print("DEVONthink MCP Security Tests")
    print("=" * 60)
    print()

    tests_passed = 0
    tests_failed = 0

    # Run each test class
    for test_class in [
        TestBasicValidation,
        TestURLValidation,
        TestFilePathValidation,
        TestAcademicIdentifierValidation,
        TestScriptValidation,
        TestSecurityConstants,
    ]:
        print(f"\n{test_class.__name__}:")
        instance = test_class()
        for method_name in dir(instance):
            if method_name.startswith('test_'):
                try:
                    getattr(instance, method_name)()
                    print(f"  ✅ {method_name}")
                    tests_passed += 1
                except Exception as e:
                    print(f"  ❌ {method_name}: {e}")
                    tests_failed += 1

    print()
    print("=" * 60)
    print(f"Results: {tests_passed} passed, {tests_failed} failed")
    print("=" * 60)

    return tests_failed == 0


if __name__ == "__main__":
    success = run_standalone_tests()
    sys.exit(0 if success else 1)
