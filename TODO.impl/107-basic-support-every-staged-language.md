# Plan 107 — Basic support for every staged dictionary language

## Why
`kotoshu setup` only serves the 32 languages with modules. Sixty-plus staged
dictionaries (from gd to ia) are unreachable: a Welsh or Icelandic user
cannot use the gem at all, even though the dictionary and model are
downloadable. Modules should be the UPGRADE (keyboard + verified specimens),
not the gate.

## Work (gem repo)
1. `LanguageCache::AVAILABLE_LANGUAGES` derives from the dictionaries
   manifest (the source the registry/staging uses) instead of the hardcoded
   module list; modules register themselves as full-feature upgrades.
2. Default behavior for module-less languages: script-appropriate tokenizer
   (reuse the script-regex machinery from plan 91), generic keyboard
   fallback (QWERTY for Latin, JCUKEN Cyrillic, Arabic 101 Arabic-script),
   setup/check/suggest all functional.
3. Wire nn (model + dictionary exist) as a full-feature module while here;
   note sr-Latn as follow-up if the Latin mapping needs product sign-off.
4. Specs: setup + specimen round trip on 3 module-less staged languages
   (e.g. is, cy, gd); full-feature languages behave identically to today;
   conformance untouched.

## Verification
Live `kotoshu setup is && check -l is` round trip; suite green; the 32
modules' outputs byte-identical.

## Status
Pending
