# Fix: Hardcover Search Results Thumbnails and Format Links

## Problem
Hardcover search results were showing:
- Blank thumbnails (no cover images)
- No audiobook or ebook buttons on hover

While Open Library search results worked correctly.

## Root Cause
The Hardcover API returns search results in a nested structure where some fields can appear at different levels:
- Some fields are nested inside `result["document"]`
- Some fields are at the `result` level directly
- The API response structure may vary

The original code only checked for `cached_image`, `has_audiobook`, and `has_ebook` inside the `document` hash, but these fields were actually at the result level in real API responses.

## Solution
Updated the `HardcoverClient` parsing methods to check both locations (result level and document level), similar to how `author_names` was already being extracted:

### Changes Made

1. **Created `extract_cover_url_from_result(result)`** - Replaces `extract_cover_url(doc)`
   - Checks `result["cached_image"]` first
   - Falls back to `result["document"]["cached_image"]`
   - Handles both string URLs and JSON object formats (`{"url": "..."}`)

2. **Created `extract_has_audiobook(result)`**
   - Checks `result["has_audiobook"]` first
   - Falls back to `result["document"]["has_audiobook"]`
   - Defaults to `false` if not found

3. **Created `extract_has_ebook(result)`**
   - Checks `result["has_ebook"]` first  
   - Falls back to `result["document"]["has_ebook"]`
   - Defaults to `false` if not found

4. **Added `extract_cover_url_from_book(book)`**
   - Separate helper for book details API (different structure)
   - Handles both string and object formats

### Test Coverage
Added comprehensive test cases:
- Fields at result level only
- Fields at document level only (existing tests)
- Mixed scenario (fields at both levels - result level takes precedence)
- JSON object format for cached_image

## Files Modified
- `app/services/hardcover_client.rb` - Core fix
- `test/services/hardcover_client_test.rb` - Added test coverage

## Verification
The fix ensures that:
1. Cover images display properly for Hardcover search results
2. Audiobook and ebook request buttons appear on hover (when formats are available)
3. The code handles various API response structures gracefully
4. Backward compatibility is maintained with existing response formats
