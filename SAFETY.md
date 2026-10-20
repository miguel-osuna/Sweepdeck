# Safety contract

## What can happen

Only explicitly selected regular files can move to macOS Trash. The sole production
mutation is `FileManager.trashItem`. There is no permanent-delete fallback, Trash
emptying, maintenance shell command, root request, privileged helper, TCC bypass,
automatic selection or launch-time scan. Do not run this app as root.

Every current rule is **Review Required**. An old or large file can still be valuable.
No file's regeneration is promised. Files moved to Trash still consume disk space.
Logical byte totals do not predict space reclaimed by APFS clones or snapshots.

## Eligibility and revalidation

Authorization stores a folder's path, device, inode, ownership/mode and ancestor
identities. Removal uses the current authorized-root list, never just a pathname.
The preview and executor validate ownership, device/inode, mode, byte size,
nanosecond modification/change times, hard-link count and flags. Ancestors must
remain directories with the same identities. The root is reauthorized against
the current policy, including repository markers. Missing, changed, excluded,
redirected or ambiguous items are refused. Exclusions use path components, so
excluding `/chosen` does not also exclude `/chosen-other`.

The production Trash adapter coordinates with `NSFileCoordinator`, checks the
coordinated path and runs validation again inside its accessor immediately before
the Trash call. There is no recursive deletion. Cancellation stops between files;
an in-flight filesystem/coordination call cannot be forcibly rolled back or interrupted.
Successfully moved files remain in Trash if a later file fails or cancellation occurs.
Each attempted file has an outcome. Preview expires after five minutes.

## Protected and skipped

- System directories, applications, all Library components, credential stores.
- Hidden files/directories, including environment files and SSH/GPG metadata.
- Git repositories and worktrees, including `.git` files; Mercurial and SVN trees.
- Known database, key, password-store, backup and Photos-library extensions.
- Node dependencies, Docker/volume directories and known cloud-storage paths.
- Symlinks and symbolic-link ancestors, aliases, packages, multi-link files.
- Cloud ubiquity, non-internal/non-local volumes, unreadable/unwritable items,
  files owned by another user and files with any special filesystem flags.

No denylist can identify every possible sensitive filename or custom sync tool.
Only authorize folders whose contents you understand. Inspect every selected file.

## Remaining race and environment limitations

Foundation's Trash API is pathname-based. File coordination protects cooperating
applications; it does not make validation + Trash atomic against malicious or
uncoordinated concurrent filesystem mutations. Repeated identity checks narrow
that window but do not eliminate it. The app is not a security boundary against
a malicious local process. Do not clean actively changing/untrusted folder trees.
The MVP deliberately rejects directory moves and known managed locations to reduce
the affected surface. Future descriptor-based designs need separate review.

File-in-use detection is not complete. Close applications using selected files.
Third-party cloud tools outside recognized paths may be indistinguishable from
local folders. Special flags and ubiquitous resources are refused without content
reads. No cloud downloads are initiated. Permission failures are shown, not bypassed.

## Permissions and storage

This local MVP is unsandboxed and unprivileged. The OS's TCC/SIP protections remain
in force. In-app authorization constrains our code; it is not OS-enforced confinement.
No Full Disk Access requirement. If macOS refuses a location, use another folder;
the app cannot grant access itself. A sandboxed distribution would require a
separate entitlement/bookmark lifecycle design and regression tests.

Corrupt/unsupported preferences are preserved; automatic overwrite and cleanup are
disabled. A save failure also disables cleanup. History saves after execution, so
a disk-write failure or crash can lose the latest journal entries. The current
in-memory result still shows them; Finder's Trash remains the recovery mechanism.

## Tests

Automated tests create unique temporary fixtures. Trash execution is injected into
a fixture-only directory. Tests never scan real Downloads, Documents, Library or
repositories and never empty the real Trash. Fixtures are removed only by their
own test utility. Production code must never acquire this test cleanup method.
