//! Kotoshu native extension (plan 66 / TODO.impl 05, P4b).
//!
//! The extension forwards its `#[magnus::init]` to the engine core's
//! Ruby bindings. `kotoshu::ffi::ruby::init` defines the `Kotoshu::Native`
//! module (`VERSION`, `available?`, `Dictionary.load` with `correct?` /
//! `suggest`); this crate contains no engine logic of its own,
//! exactly like kotoshu-rs' `tests/ruby_ext` reference shim and
//! parsanol-ruby's `ext/parsanol_native`.
//!
//! One binding lives here instead of the core crate: the language
//! identification surface (plan 106). `LidModel.load` +
//! `LidModel#detect` wrap `kotoshu::lid::LidModel` — the pure-Rust
//! reader for the `kotoshu://models/lid/lid-176` artifact pair —
//! behind the same `model` feature the core crate ships it under
//! (see the features table in Cargo.toml). Only the magnus glue is
//! gem-side; every scoring decision stays in the core, where the
//! parity suite freezes it against the shared frozen corpus.

use std::path::Path;

use magnus::typed_data::Obj;
use magnus::typed_data::TypedData;
use magnus::value::Lazy;
use magnus::{
    Class, DataType, DataTypeFunctions, Error, ExceptionClass, Module, Object, RClass, RHash,
    RModule, Ruby, data_type_builder, method,
};

/// The `Kotoshu` module, defined (idempotently) on first access — the
/// same helper shape as the core crate's `ffi::ruby`.
fn kotoshu_module(ruby: &Ruby) -> RModule {
    static MODULE: Lazy<RModule> = Lazy::new(|ruby| {
        ruby.define_module("Kotoshu")
            .expect("cannot define Kotoshu module")
    });
    ruby.get_inner(&MODULE)
}

/// The `Kotoshu::Native` module hosting the engine bindings.
fn native_module(ruby: &Ruby) -> RModule {
    static MODULE: Lazy<RModule> = Lazy::new(|ruby| {
        kotoshu_module(ruby)
            .define_module("Native")
            .expect("cannot define Kotoshu::Native module")
    });
    ruby.get_inner(&MODULE)
}

/// `Kotoshu::Native::Error`, defined by the core crate's init — every
/// LID failure crosses the boundary as the same exception class the
/// dictionary surface raises.
fn error_class(ruby: &Ruby) -> ExceptionClass {
    static CLASS: Lazy<ExceptionClass> = Lazy::new(|ruby| {
        native_module(ruby)
            .const_get::<_, ExceptionClass>("Error")
            .expect("Kotoshu::Native::Error not defined after ffi::ruby::init")
    });
    ruby.get_inner(&CLASS)
}

/// A loaded LID model wrapped as a Ruby object: the twin of the core
/// crate's `RubyDictionary`. Ruby's GC owns it once wrapped; dropping
/// the Ruby object drops the engine model (~1 MB of int8 rows plus
/// ~1.8 MB of sidecar tables, roughly the artifact pair's own size).
#[derive(Debug)]
pub struct RubyLidModel {
    inner: kotoshu::lid::LidModel,
}

// Plain owned data; Ruby objects move between threads only with the
// GVL held, which TypedData's Send bound models.
impl DataTypeFunctions for RubyLidModel {}

unsafe impl TypedData for RubyLidModel {
    fn class(ruby: &Ruby) -> RClass {
        static CLASS: Lazy<RClass> = Lazy::new(|ruby| {
            let class = native_module(ruby)
                .define_class("LidModel", ruby.class_object())
                .expect("cannot define Kotoshu::Native::LidModel");
            // Instances exist only through `LidModel.load`; `new`/
            // `allocate` would produce a model-less object.
            class.undef_default_alloc_func();
            class
        });
        ruby.get_inner(&CLASS)
    }

    fn data_type() -> &'static DataType {
        static DATA_TYPE: DataType =
            data_type_builder!(RubyLidModel, "Kotoshu/Native/LidModel").build();
        &DATA_TYPE
    }
}

/// `Kotoshu::Native::LidModel.load(onnx_path, vocab_path)` — reads the
/// registry artifact pair (the `lid.176.onnx` container and its
/// `lid.176.vocab.json` sidecar) and wraps the parsed model. Failures
/// raise `Kotoshu::Native::Error` carrying the Rust error message,
/// mirroring `Dictionary.load`.
fn lid_model_load(
    ruby: &Ruby,
    _class: RClass,
    onnx_path: String,
    vocab_path: String,
) -> Result<Obj<RubyLidModel>, Error> {
    let fail = |message: String| {
        Error::new(
            error_class(ruby),
            format!("failed to load LID model ({onnx_path}, {vocab_path}): {message}"),
        )
    };

    let onnx_bytes =
        std::fs::read(Path::new(&onnx_path)).map_err(|error| fail(error.to_string()))?;
    let vocab_bytes =
        std::fs::read(Path::new(&vocab_path)).map_err(|error| fail(error.to_string()))?;
    let model = kotoshu::lid::LidModel::parse(&onnx_bytes, &vocab_bytes)
        .map_err(|error| fail(error.to_string()))?;
    Ok(ruby.obj_wrap(RubyLidModel { inner: model }))
}

/// `Kotoshu::Native::LidModel#detect(text)` — the top label and its
/// probability as `{ "code" => String, "score" => Float }`, the gem's
/// `LanguageIdentifier` detection pair (labels equal and scores within
/// 5e-4 of the fastText bindings; frozen by the kotoshu-rs parity
/// suite over the shared corpus fixture).
fn lid_model_detect(ruby: &Ruby, rb_self: &RubyLidModel, text: String) -> Result<RHash, Error> {
    let detection = rb_self.inner.detect(&text);
    let hash = ruby.hash_new();
    hash.aset("code", detection.code.as_str())?;
    hash.aset("score", detection.score)?;
    Ok(hash)
}

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    kotoshu::ffi::ruby::init(ruby)?;

    let class = RubyLidModel::class(ruby);
    class.define_singleton_method("load", method!(lid_model_load, 2))?;
    class.define_method("detect", method!(lid_model_detect, 1))?;
    Ok(())
}
