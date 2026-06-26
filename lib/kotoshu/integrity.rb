# frozen_string_literal: true

module Kotoshu
  # Integrity verification for downloaded resources.
  #
  # Two cooperating pieces:
  #
  # - {Manifest} — parsed view of a content repo's `manifest.json`. Lookup
  #   by relative path yields the expected SHA-256 and size.
  # - {AuditLog} — append-only JSON log at `$XDG_DATA_HOME/kotoshu/audit.log` recording
  #   every download's URL, size, computed SHA-256, manifest hash (when
  #   available), and status.
  #
  # Caches call `Manifest.verify_content!` after each download. If the
  # manifest is absent (the upstream repo hasn't shipped one yet), the
  # caller logs the download with status `"unverified"` and proceeds —
  # graceful degradation. When a manifest IS present and the SHA-256
  # doesn't match, {Kotoshu::IntegrityError} is raised and the corrupt
  # bytes are removed before they reach the cache.
  module Integrity
    autoload :Manifest, "kotoshu/integrity/manifest"
    autoload :AuditLog, "kotoshu/integrity/audit_log"
    autoload :NetHTTP, "kotoshu/integrity/net_http"
  end
end
