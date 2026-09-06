# 21 — Migrate require_relative to autoload (T3, deferred past 0.3)

## Status
Deferred past 0.3 release. Documented for 0.4.

## Problem
288 `require_relative` calls in `lib/`. Per `~/.claude/CLAUDE.md`:

> NEVER use `require_relative` for internal library code. Never use
> `require` with a path to code within your own library. Use Ruby
> `autoload` instead. Define autoload entries in the immediate parent
> namespace's file — create that file if it doesn't exist.

Current state:
- `lib/kotoshu.rb` eagerly `require_relative`s the traditional path
  (core models, dictionaries, strategies, configuration, spellchecker)
  and uses `autoload` for the rest.
- Many subdirs lack a parent-namespace file (e.g. `lib/kotoshu/models.rb`
  does not exist).

## Plan

### Phase 1 — Create missing parent namespace files
Create each of:
```
lib/kotoshu/models.rb
lib/kotoshu/dictionaries.rb
lib/kotoshu/dictionary.rb
lib/kotoshu/suggestions.rb
lib/kotoshu/analyzers.rb
lib/kotoshu/documents.rb
lib/kotoshu/components.rb
lib/kotoshu/plugins.rb
lib/kotoshu/data_structures.rb
lib/kotoshu/results.rb
lib/kotoshu/commands.rb
```
Each declares `module Kotoshu::<Ns>` with one `autoload :ClassName,
"kotoshu/<ns>/<class_name_in_snake_case>"` per file in the subdir.

### Phase 2 — Replace require_relative inside lib/
Inside `lib/kotoshu/**/*.rb`:
- Replace `require_relative "foo"` with `autoload :Foo, "kotoshu/<ns>/foo"`.
- The autoload declaration lives in the immediate parent namespace file
  (created in Phase 1), not in the file that needs the class.
- The top-level `lib/kotoshu.rb` only `require_relative`s the namespace
  files (`kotoshu/cache`, `kotoshu/models`, etc.), not individual classes.

### Phase 3 — Verify eager paths still work
Some classes must still load eagerly (the public facade in `lib/kotoshu.rb`).
Keep those as `require_relative "kotoshu/<ns>"` (which loads the parent
namespace file, which can either autoload or eager-require its children).

## Acceptance

- [ ] `grep -rn "require_relative" lib/ | wc -l` is ≤ ~10 (only top-level
      `lib/kotoshu.rb` loading namespace files).
- [ ] `bundle exec rspec` passes with no regressions.
- [ ] Boot time (`bundle exec ruby -e 'require "kotoshu"; puts Kotoshu'`)
      is no slower than today (autoload should make it faster).

## Why deferred
Touches every file in `lib/`. High regression surface. New 0.3 code
follows the autoload rule; full migration is a dedicated 0.4 effort.
