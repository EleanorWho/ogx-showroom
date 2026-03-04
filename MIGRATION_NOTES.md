# RHOAI Version Migration Notes

This file tracks breaking changes and behavioral differences between RHOAI versions
that required code changes in this repository.

## RHOAI 3.4ea1 (from 3.3)

### Vector Store API - HTTP 204 Response
**Impact:** Breaking change
**Component:** LlamaStack vector-io insert endpoint
**Files affected:**
- `scripts/rag-demo.py`

**Description:**
The vector insertion endpoint (`/v1/vector-io/insert`) now returns HTTP 204 No Content
on successful insertion instead of HTTP 200. This is a valid REST pattern for operations
that don't return data, but breaks clients that only check for 200/201 status codes.

**Change required:**
Updated accepted status codes from `[200, 201]` to `[200, 201, 204]` in the
`insert_vectors()` method.

---

## Future versions

<!-- Template:
### Feature/API Name
**Impact:** Breaking change | Behavior change | Deprecation
**Component:** Component name
**Files affected:**
- file1
- file2

**Description:**
What changed and why.

**Change required:**
What we had to do to fix it.
-->
