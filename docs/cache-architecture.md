# Kotoshu Cache System Architecture

## Overview

The Kotoshu cache system provides a unified, object-oriented architecture for managing linguistic resources (dictionaries, frequency lists, and embedding models). The system implements automatic download, local caching, metadata management, and TTL-based expiration.

## Design Principles

### 1. DRY (Don't Repeat Yourself)
All cache types inherit from `BaseCache`, eliminating code duplication for:
- HTTP downloads
- Metadata serialization/deserialization
- Cache validation (existence, expiration)
- Statistics tracking (hits, misses, hit rate)
- TTL management

### 2. OOP (Object-Oriented Programming)
- Abstract base class defines the interface
- Concrete implementations provide type-specific behavior
- Template Method pattern for extensible operations
- Strategy pattern for resource type handling

### 3. Separation of Concerns
- `BaseCache`: Common cache operations
- `LanguageCache`: Dictionary and grammar resources
- `ModelCache`: Embedding model resources
- `FrequencyCache`: Frequency list resources

### 4. Single Responsibility
Each cache class has one responsibility:
- LanguageCache manages dictionaries
- ModelCache manages models
- FrequencyCache manages frequency lists

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Application Layer                             │
│  (Kotoshu::SpellChecker, Kotoshu::Suggestions::Strategies::EditDistance) │
└─────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Cache Interface Layer                          │
│                            (CLI: kotoshu cache ...)                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
                    ▼                     ▼                     ▼
┌───────────────────────────┐ ┌──────────────────┐ ┌─────────────────────────┐
│   LanguageCache          │ │   ModelCache     │ │   FrequencyCache        │
│   (Dictionaries)         │ │   (Embeddings)    │ │   (Kelly Lists)         │
├───────────────────────────┤ ├──────────────────┤ ├─────────────────────────┤
│ + get_spelling()         │ │ + get_fasttext() │ │ + get_frequency()       │
│ + get_grammar()          │ │ + get_onnx()     │ │ + available_languages()  │
│ + available_languages()  │ │ + available_...  │ │                         │
└───────────┬───────────────┘ └──────┬───────────┘ └───────────┬─────────────┘
            │                          │                        │
            │                          │                        │
            ▼                          ▼                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              BaseCache (Abstract)                        │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │ Public API                                                            │  │
│  │  + get(resource_id, force_download: false)                         │  │
│  │  + available?(resource_id)                                          │  │
│  │  + clear(resource_id)                                                │  │
│  │  + clear_all()                                                       │  │
│  │  + stats                                                              │  │
│  │  + clean()                                                            │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │ Protected Abstract Methods (subclasses must implement)               │  │
│  │  + download_resource(resource_id, dest_path)                        │  │
│  │  + load_cached(resource_id)                                         │  │
│  │  + metadata_path_for(resource_id)                                   │  │
│  │  + resource_dir_for(resource_id)                                    │  │
│  │  + resource_files_exist?(resource_id)                                │  │
│  │  + supports_resource?(resource_id)                                   │  │
│  │  + cached_resources                                                 │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │ Protected Helper Methods (available to subclasses)                  │  │
│  │  + download_url(url)                                                │  │
│  │  + download_file(url, dest_path)                                   │  │
│  │  + write_metadata(path, metadata)                                  │  │
│  │  + read_metadata(path)                                              │  │
│  │  + cached?(metadata_path)                                           │  │
│  │  + expired?(metadata_path)                                          │  │
│  │  + checksum(content)                                                │  │
│  │  + parse_resource_id(resource_id)                                   │  │
│  │  + extract_language(resource_id)                                    │  │
│  │  + extract_type(resource_id)                                        │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │ Private Methods                                                      │  │
│  │  + default_cache_path                                               │  │
│  │  + default_url_base                                                 │  │
│  │  + default_cache_ttl                                                │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
                    ▼                     ▼                     ▼
        ┌─────────────────────┐ ┌──────────────┐ ┌─────────────────────────┐
        │ ~/.kotoshu/          │ │ ~/.kotoshu/   │ │ ~/.kotoshu/             │
        │   languages/         │ │   models/     │ │   frequency-lists/      │
        │ ┌─────────────────┐ │ │ ┌──────────┐ │ │ ┌─────────────────────┐ │
        │ │ en/              │ │ │ │ en/       │ │ │ │ en/                  │ │
        │ │ ├── spelling/    │ │ │ │ └──models/│ │ │ │ ├── frequency.json  │ │
        │ │ │   ├── index.dic│ │ │ │   fasttext│ │ │ │ └── metadata.json   │ │
        │ │ │   └── index.aff│ │ │ │   onnx/   │ │ │ └─────────────────────┘ │
        │ │ └── metadata.json│ │ │ │   fasttext│ │ │                         │
        │ └─────────────────┘ │ │ │   onnx    │ │ │ ru/, ar/, etc.          │
        │ de/, es/, fr/, etc.  │ │ └──────────┘ │ │                         │
        └─────────────────────┘ └──────────────┘ └─────────────────────────┘
```

## Resource ID Format

All resources use a colon-separated identifier format: `{language}:{type}`

### Examples
- `en:spelling` - English spelling dictionary
- `en:fasttext` - English FastText model
- `en:frequency` - English frequency data (deprecated, use FrequencyCache)
- `ru:spelling` - Russian spelling dictionary
- `de:onnx` - German ONNX model
- `en:onnx:mini` - English mini-tier ONNX model (tiered form `{language}:onnx:{tier}`; tiers are `full`, `fluency`, `mini`; `full` uses the legacy two-part id)

## Model Tiers and the Registry

`ModelCache` supports tiered ONNX model resources (`full`, `fluency`, `mini`), resolved through the resource registry (`registry.json`) published by `kotoshu/models-fasttext-onnx` under stable ids (`kotoshu://models/{lang}/{tier}`). Approximate sizes: `full` ~120 MB, `fluency` ~15-18 MB, `mini` ~3 MB.

### Tiered on-disk layout

Tiered resource ids carry a third segment (`{language}:onnx:{tier}`). The `full` tier keeps the legacy two-part id (`{language}:onnx`) and the legacy on-disk layout, preserved byte-compatibly; `fluency` and `mini` nest under the onnx directory as sibling directories so tiers coexist:

```
{model cache}/
└── en/
    └── models/
        ├── fasttext/
        └── onnx/                      # full tier (legacy layout, unchanged)
            ├── fasttext.en.onnx
            ├── fasttext.en.vocab.json
            ├── metadata.json
            ├── mini/                  # tiered siblings
            │   ├── fasttext.en.mini.onnx
            │   ├── fasttext.en.mini.vocab.json
            │   └── metadata.json
            └── fluency/
                └── ...
```

`ModelCache#cached_tiers(language)` lists the tiers currently cached for a language with a disk-only lookup (it never touches the network, so it is resolve-safe), in the fixed preference order `mini`, `fluency`, `full`. That order exists so ambiguity errors are deterministic across machines and runs — it is a reporting order, not a fallback chain; tiers are never silently substituted.

### The cached registry

`registry.json` is fetched at most once per cache instance and stored under `{model cache}/registry/`:

- `registry.json` — the raw registry bytes
- `metadata.json` — records the bytes' own SHA-256, source URL, and fetch time

The cached copy is reused while fresh (subject to the cache TTL). A copy that is absent, unparsable, or fails its recorded SHA-256 is treated as unusable and re-fetched rather than trusted.

`KOTOSHU_OFFLINE=1`: the registry is never fetched. A cached copy — even a stale one — is reused; when none is cached, `Kotoshu::Error` is raised (run once online, or copy `registry.json` there first).

The resolve path never consults the registry at all. It is cache-only, so a missing tier raises `ResourceNotSetupError` exactly like any other unset resource — resolve never downloads and never falls back to another tier.

### Download and verification

Tiered downloads (`ModelCache#download_tiered_model`) raise rather than degrade to `nil`, so setup callers can report `:unavailable`:

1. Look up the `(language, tier)` entry in the registry. No entry means the language publishes no such tier.
2. Download the model from `urls.primary`, falling back to `urls.mirror` (partial bytes from a failed attempt are removed first).
3. Verify the downloaded bytes' SHA-256 against the registry entry. On mismatch the corrupt file is deleted, the mismatch is recorded in the audit log, and `Kotoshu::IntegrityError` is raised with a remediation hint.
4. Download the vocab sibling (a missing vocab is a warning, not a failure).

## Cache Lifecycle

### 1. Initial Access (Cache Miss)

```
User calls cache.get('en:spelling')
         │
         ▼
BaseCache.get() checks:
  - supports_resource?('en:spelling') → true
  - cached?(metadata_path) → false (first access)
         │
         ▼
Download triggered:
  - download_resource('en:spelling', dest_path)
  - download_file(url, dest_path)
  - write_metadata(metadata_path, metadata)
  - track_miss
         │
         ▼
Return: { aff_path, dic_path, cached: false, metadata }
```

### 2. Subsequent Access (Cache Hit)

```
User calls cache.get('en:spelling')
         │
         ▼
BaseCache.get() checks:
  - supports_resource?('en:spelling') → true
  - cached?(metadata_path) → true
  - expired?(metadata_path) → false (within TTL)
         │
         ▼
Load from cache:
  - load_cached('en:spelling')
  - read_metadata(metadata_path)
  - track_hit
         │
         ▼
Return: { aff_path, dic_path, cached: true, metadata }
```

### 3. Expired Cache Access

```
User calls cache.get('en:spelling')
         │
         ▼
BaseCache.get() checks:
  - supports_resource?('en:spelling') → true
  - cached?(metadata_path) → true
  - expired?(metadata_path) → true (older than 7 days)
         │
         ▼
Re-download triggered:
  - download_resource('en:spelling', dest_path)
  - (same as initial access)
```

## Metadata Format

All cached resources include metadata in JSON format:

```json
{
  "version": "2025-01-15T10:30:00Z",
  "url": "https://raw.githubusercontent.com/...",
  "language": "en",
  "type": "spelling",
  "checksum": "a1b2c3d4e5f6...",
  "cached_at": "2025-01-15T10:30:00Z"
}
```

### Metadata Fields
- `version`: Timestamp when resource was cached
- `url`: Source URL for the resource
- `language`: ISO 639-1 language code
- `type`: Resource type (spelling, grammar, fasttext, onnx, kelly_frequency)
- `checksum`: SHA256 checksum for integrity verification
- `cached_at`: Timestamp of caching

## Thread Safety

The cache system is designed for single-threaded use. For multi-threaded environments:

1. **Process-based parallelism**: Each process has its own cache
2. **File locking**: Not implemented (future enhancement)
3. **Recommended**: Use separate cache instances per thread

## Error Handling

### Download Failures
- HTTP errors raise `RuntimeError` with details
- Invalid JSON raises `JSON::ParserError`
- File I/O errors propagate to caller

### Cache Validation
- Missing metadata returns `nil`
- Expired cache triggers re-download
- Invalid checksum triggers re-download (future)

## Performance Considerations

### Cache Hit Rates
Target hit rates by cache type:
- **LanguageCache**: 85-95% (dictionaries rarely change)
- **FrequencyCache**: 95-99% (frequency lists very stable)
- **ModelCache**: 98-99% (models rarely change)

### Disk Usage
Typical disk usage per language:
- **Dictionary**: ~2-4 MB (Hunspell files)
- **Frequency**: ~800 KB (Kelly JSON)
- **Models**: ~600-2000 MB (FastText vectors, varies by language)

### Download Speeds
Typical download times (broadband):
- **Dictionary**: 2-5 seconds
- **Frequency**: 1-2 seconds
- **Models**: 30-120 seconds (large files)

## Extending the Cache System

### Adding a New Cache Type

1. **Create subclass of BaseCache**:

```ruby
class MyCache < Kotoshu::Cache::BaseCache
  def initialize(cache_path: nil, url_base: nil, cache_ttl: nil)
    super
  end

  protected

  def download_resource(resource_id, dest_path)
    # Download logic
  end

  def load_cached(resource_id)
    # Load logic
  end

  def metadata_path_for(resource_id)
    # Return path to metadata.json
  end

  def resource_dir_for(resource_id)
    # Return directory path
  end

  def resource_files_exist?(resource_id)
    # Check if files exist
  end

  def supports_resource?(resource_id)
    # Check if resource is supported
  end

  def cached_resources
    # Return list of cached resource IDs
  end
end
```

2. **Implement abstract methods**
3. **Set appropriate TTL** (override `default_cache_ttl`)
4. **Set cache path** (override `default_cache_path`)

### Downloading from External Sources

For resources hosted outside GitHub (like FastText models), override the
download logic and URL generation:

```ruby
def model_url(language, type, filename)
  case type
  when "fasttext"
    # Download from FastText CDN (Facebook Research)
    # https://dl.fbaipublicfiles.com/fasttext/vectors-crawl/
    "https://dl.fbaipublicfiles.com/fasttext/vectors-crawl/#{filename}"
  else
    "#{@url_base}/default/path/#{filename}"
  end
end

def download_resource(resource_id, dest_path)
  # ... existing code ...

  filename = model_info[:file]

  # Handle gzip compression
  if filename.end_with?('.gz')
    download_and_decompress(url, dest_path)
  else
    download_file(url, dest_path)
  end
end

def download_and_decompress(url, dest_path)
  # Download to temporary .gz file
  temp_gz = "#{dest_path}.gz"
  URI.open(url, open_timeout: 30, read_timeout: 300) do |uri|
    File.write(temp_gz, uri.read, mode: 'wb')
  end

  # Decompress gzip
  Zlib::GzipReader.open(temp_gz) do |gz|
    File.write(dest_path, gz.read)
  end

  File.delete(temp_gz)
end
```

### FastText Model Sources

FastText models are downloaded from Facebook's public CDN:

- **Base URL**: `https://dl.fbaipublicfiles.com/fasttext/vectors-crawl/`
- **Files**: `cc.{lang}.300.vec.gz` (gzipped FastText vectors)
- **Decompressed**: `cc.{lang}.300.vec` (text format, 300 dimensions)
- **Sizes**: ~1.2-2.7 GB per language (decompressed)

.File sizes by language
[width="100%",cols="^1,^1,^1",options="header"]
|=========================================
| Language | Compressed | Decompressed | Word Count  |
|=========================================
| de (German)       | 1.2 GB | ~2.5 GB | 1,000,000   |
| en (English)      | 2.7 GB | ~5.0 GB | 2,000,000   |
| es (Spanish)      | 1.2 GB | ~2.5 GB | 1,000,000   |
| fr (French)       | 1.2 GB | ~2.5 GB | 1,000,000   |
| pt (Portuguese)   | 1.2 GB | ~2.5 GB | 1,000,000   |
| ru (Russian)      | 1.2 GB | ~2.5 GB | 1,000,000   |
|=========================================]

### Adding CLI Commands

To add CLI commands for a new cache type, edit `lib/kotoshu/commands/cache_command.rb`:

```ruby
desc 'download TYPE RESOURCE', 'Download a resource from GitHub'
def download(type, resource)
  cache = cache_for_type(type)

  case type
  when 'mycache', 'mc'
    download_mycache(cache, resource)
  end
end

private

def download_mycache(cache, resource)
  result = cache.get(resource, force_download: options[:force])
  puts "Downloaded: #{result[:path]}"
end

def cache_for_type(type)
  case type
  when 'mycache', 'mc'
    MyCache.new
  # ... existing types
  end
end
```

## Testing

### Unit Tests
Each cache type has comprehensive RSpec tests:
- `spec/kotoshu/cache/language_cache_spec.rb`
- `spec/kotoshu/cache/model_cache_spec.rb`
- `spec/kotoshu/cache/frequency_cache_spec.rb`

### Integration Tests
Run combined cache test:
```bash
ruby test_combined_cache.rb
```

## Troubleshooting

### Cache Not Downloading
Check:
1. Internet connection
2. GitHub repository accessibility
3. Available disk space
4. File permissions on `~/.kotoshu/`

### Stale Cache Data
Force re-download:
```ruby
cache.get('en:spelling', force_download: true)
```

Or use CLI:
```bash
kotoshu cache download language en
kotoshu cache purge language en
kotoshu cache download language en
```

### High Cache Miss Rate
- Check TTL settings
- Verify cache directory exists
- Check metadata files are valid JSON

## Future Enhancements

1. **File Locking**: Support multi-threaded access
2. **Compression**: Compress cached models to save disk space
3. **Partial Downloads**: Resume interrupted downloads
4. **Cache Warming**: Pre-download frequently used resources
5. **Distributed Caching**: Support Redis/memcached backends
6. **Incremental Updates**: Update only changed resources
