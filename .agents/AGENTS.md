# FlockKeeper Workspace Customization Rules

- **Automatic Version and Build Versioning:** Whenever significant changes, bug fixes, or new features are introduced to the codebase, automatically increment the build number (the number after the `+` sign) and/or version numbers in `pubspec.yaml` depending on complexity before compiling release packages.
  - *Patch/Build increments (+1 to build number)*: For standard bug fixes, small feature tweaks, or UI enhancements.
  - *Minor version increments (e.g., 1.0.1 -> 1.0.2)*: For larger standalone features, new screen additions, or system-wide tool improvements.
  - *Major version increments (e.g., 1.0.1 -> 1.1.0)*: For major architectural changes or fundamental additions (like database schema changes or new platform expansions).
