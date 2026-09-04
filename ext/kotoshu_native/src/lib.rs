//! Kotoshu native extension (plan 66 / TODO.impl 05, P4b).
//!
//! The whole extension: a `#[magnus::init]` that forwards to the engine
//! core's Ruby bindings. `kotoshu::ffi::ruby::init` defines the
//! `Kotoshu::Native` module (`VERSION`, `available?`, `Dictionary.load`
//! with `correct?` / `suggest`); this crate contains no logic of its own,
//! exactly like kotoshu-rs' `tests/ruby_ext` reference shim and
//! parsanol-ruby's `ext/parsanol_native`.

use magnus::{Error, Ruby};

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    kotoshu::ffi::ruby::init(ruby)
}
