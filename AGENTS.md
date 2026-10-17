# Repository Agent Instructions

## Before changing catalog UI

1. Read `image/README.md` before editing catalog UI or avatar/catalog presentation.
2. Query the current contents of `image/` on the branch being changed. Do not assume the index is current or that a filename from an earlier conversation still exists.
3. Identify relevant screenshots and documents by their actual repository paths and filenames. Filenames may contain spaces, Korean characters, or invisible Unicode direction-control characters; copy paths from GitHub's file listing/API rather than retyping them.
4. Use the GitHub Raw URL form for reference files: `https://raw.githubusercontent.com/{owner}/{repo}/{branch}/{path}`. Convert a Blob URL by replacing `github.com` with `raw.githubusercontent.com` and removing only the `/blob/` segment. Preserve the branch and exact encoded path.
5. Verify that the resulting URL actually opens before relying on it. Constructing a URL is not proof that the file is accessible.
6. Inspect PNG/JPG and other image files as images. Inspect PDFs with a PDF-capable reader or page extraction; do not assume a PDF should render as a single image.
7. If a file cannot be accessed or its contents cannot be read, state that limitation and do not claim to have reviewed it.

## Keeping references current

Whenever files are added, renamed, or removed in `image/`, update `image/README.md` in the same change with the exact filename, type, purpose when known, and Raw URL. Do not rename reference assets merely to simplify their URLs unless explicitly requested.

## Scope

Keep changes focused on the requested task. Use the repository's existing documentation as the source of truth for game design and implementation decisions.
