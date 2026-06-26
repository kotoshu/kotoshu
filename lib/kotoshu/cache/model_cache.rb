# frozen_string_literal: true

require_relative "base_cache"
require "zlib"
require "open-uri"
require "open3"

module Kotoshu
  module Cache
    # Manages embedding model downloads from FastText CDN and GitHub.
    #
    # Extends BaseCache to support FastText .vec files and ONNX models.
    # Downloads FastText models from Facebook's public CDN.
    #
    # @example Downloading a FastText model
    #   cache = ModelCache.new
    #   vec_file = cache.get_fasttext_model('en')
    #   model = FastTextModel.from_file(vec_file)
    #
    # @example Downloading an ONNX model
    #   onnx_file = cache.get_onnx_model('en')
    class ModelCache < BaseCache
      # Available models in FastText CDN and models-fasttext-onnx repository
      AVAILABLE_MODELS = {
        # FastText crawl vectors (300D) from Facebook Research
        # https://dl.fbaipublicfiles.com/fasttext/vectors-crawl/
        # Selected high-resource languages
        fasttext: {
          de: { file: "cc.de.300.vec.gz", size: 1_000_000, source: "FastText Common Crawl" },
          en: { file: "cc.en.300.vec.gz", size: 2_000_000, source: "FastText Common Crawl" },
          es: { file: "cc.es.300.vec.gz", size: 1_000_000, source: "FastText Common Crawl" },
          fr: { file: "cc.fr.300.vec.gz", size: 1_000_000, source: "FastText Common Crawl" },
          pt: { file: "cc.pt.300.vec.gz", size: 1_000_000, source: "FastText Common Crawl" },
          ru: { file: "cc.ru.300.vec.gz", size: 1_000_000, source: "FastText Common Crawl" }
        },
        # ONNX models (157 languages) from models-fasttext-onnx repository
        # Converted from FastText .vec files with 100K vocabulary, 300D embeddings
        # https://github.com/kotoshu/models-fasttext-onnx
        onnx: {
          # Full list of 157 language codes
          af: { file: "fasttext.af.onnx", size: 500_000, source: "models-fasttext-onnx" },
          als: { file: "fasttext.als.onnx", size: 500_000, source: "models-fasttext-onnx" },
          am: { file: "fasttext.am.onnx", size: 500_000, source: "models-fasttext-onnx" },
          an: { file: "fasttext.an.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ar: { file: "fasttext.ar.onnx", size: 500_000, source: "models-fasttext-onnx" },
          arz: { file: "fasttext.arz.onnx", size: 500_000, source: "models-fasttext-onnx" },
          as: { file: "fasttext.as.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ast: { file: "fasttext.ast.onnx", size: 500_000, source: "models-fasttext-onnx" },
          av: { file: "fasttext.av.onnx", size: 500_000, source: "models-fasttext-onnx" },
          az: { file: "fasttext.az.onnx", size: 500_000, source: "models-fasttext-onnx" },
          azj: { file: "fasttext.azj.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ba: { file: "fasttext.ba.onnx", size: 500_000, source: "models-fasttext-onnx" },
          bar: { file: "fasttext.bar.onnx", size: 500_000, source: "models-fasttext-onnx" },
          bcl: { file: "fasttext.bcl.onnx", size: 500_000, source: "models-fasttext-onnx" },
          be: { file: "fasttext.be.onnx", size: 500_000, source: "models-fasttext-onnx" },
          bg: { file: "fasttext.bg.onnx", size: 500_000, source: "models-fasttext-onnx" },
          bh: { file: "fasttext.bh.onnx", size: 500_000, source: "models-fasttext-onnx" },
          bm: { file: "fasttext.bm.onnx", size: 500_000, source: "models-fasttext-onnx" },
          bn: { file: "fasttext.bn.onnx", size: 500_000, source: "models-fasttext-onnx" },
          bo: { file: "fasttext.bo.onnx", size: 500_000, source: "models-fasttext-onnx" },
          br: { file: "fasttext.br.onnx", size: 500_000, source: "models-fasttext-onnx" },
          bs: { file: "fasttext.bs.onnx", size: 500_000, source: "models-fasttext-onnx" },
          bxr: { file: "fasttext.bxr.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ca: { file: "fasttext.ca.onnx", size: 500_000, source: "models-fasttext-onnx" },
          cbk: { file: "fasttext.cbk.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ce: { file: "fasttext.ce.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ceb: { file: "fasttext.ceb.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ckb: { file: "fasttext.ckb.onnx", size: 500_000, source: "models-fasttext-onnx" },
          cmn: { file: "fasttext.cmn.onnx", size: 500_000, source: "models-fasttext-onnx" },
          co: { file: "fasttext.co.onnx", size: 500_000, source: "models-fasttext-onnx" },
          cs: { file: "fasttext.cs.onnx", size: 500_000, source: "models-fasttext-onnx" },
          cv: { file: "fasttext.cv.onnx", size: 500_000, source: "models-fasttext-onnx" },
          cy: { file: "fasttext.cy.onnx", size: 500_000, source: "models-fasttext-onnx" },
          da: { file: "fasttext.da.onnx", size: 500_000, source: "models-fasttext-onnx" },
          de: { file: "fasttext.de.onnx", size: 500_000, source: "models-fasttext-onnx" },
          diq: { file: "fasttext.diq.onnx", size: 500_000, source: "models-fasttext-onnx" },
          dsb: { file: "fasttext.dsb.onnx", size: 500_000, source: "models-fasttext-onnx" },
          dty: { file: "fasttext.dty.onnx", size: 500_000, source: "models-fasttext-onnx" },
          dv: { file: "fasttext.dv.onnx", size: 500_000, source: "models-fasttext-onnx" },
          el: { file: "fasttext.el.onnx", size: 500_000, source: "models-fasttext-onnx" },
          en: { file: "fasttext.en.onnx", size: 1_000_000, source: "models-fasttext-onnx" },
          eo: { file: "fasttext.eo.onnx", size: 500_000, source: "models-fasttext-onnx" },
          es: { file: "fasttext.es.onnx", size: 500_000, source: "models-fasttext-onnx" },
          et: { file: "fasttext.et.onnx", size: 500_000, source: "models-fasttext-onnx" },
          eu: { file: "fasttext.eu.onnx", size: 500_000, source: "models-fasttext-onnx" },
          fa: { file: "fasttext.fa.onnx", size: 500_000, source: "models-fasttext-onnx" },
          fi: { file: "fasttext.fi.onnx", size: 500_000, source: "models-fasttext-onnx" },
          fr: { file: "fasttext.fr.onnx", size: 500_000, source: "models-fasttext-onnx" },
          frr: { file: "fasttext.frr.onnx", size: 500_000, source: "models-fasttext-onnx" },
          fy: { file: "fasttext.fy.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ga: { file: "fasttext.ga.onnx", size: 500_000, source: "models-fasttext-onnx" },
          gd: { file: "fasttext.gd.onnx", size: 500_000, source: "models-fasttext-onnx" },
          gl: { file: "fasttext.gl.onnx", size: 500_000, source: "models-fasttext-onnx" },
          gn: { file: "fasttext.gn.onnx", size: 500_000, source: "models-fasttext-onnx" },
          gom: { file: "fasttext.gom.onnx", size: 500_000, source: "models-fasttext-onnx" },
          gu: { file: "fasttext.gu.onnx", size: 500_000, source: "models-fasttext-onnx" },
          gv: { file: "fasttext.gv.onnx", size: 500_000, source: "models-fasttext-onnx" },
          he: { file: "fasttext.he.onnx", size: 500_000, source: "models-fasttext-onnx" },
          hi: { file: "fasttext.hi.onnx", size: 500_000, source: "models-fasttext-onnx" },
          hif: { file: "fasttext.hif.onnx", size: 500_000, source: "models-fasttext-onnx" },
          hr: { file: "fasttext.hr.onnx", size: 500_000, source: "models-fasttext-onnx" },
          hsb: { file: "fasttext.hsb.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ht: { file: "fasttext.ht.onnx", size: 500_000, source: "models-fasttext-onnx" },
          hu: { file: "fasttext.hu.onnx", size: 500_000, source: "models-fasttext-onnx" },
          hy: { file: "fasttext.hy.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ia: { file: "fasttext.ia.onnx", size: 500_000, source: "models-fasttext-onnx" },
          id: { file: "fasttext.id.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ie: { file: "fasttext.ie.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ilo: { file: "fasttext.ilo.onnx", size: 500_000, source: "models-fasttext-onnx" },
          io: { file: "fasttext.io.onnx", size: 500_000, source: "models-fasttext-onnx" },
          is: { file: "fasttext.is.onnx", size: 500_000, source: "models-fasttext-onnx" },
          it: { file: "fasttext.it.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ja: { file: "fasttext.ja.onnx", size: 500_000, source: "models-fasttext-onnx" },
          jbo: { file: "fasttext.jbo.onnx", size: 500_000, source: "models-fasttext-onnx" },
          jv: { file: "fasttext.jv.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ka: { file: "fasttext.ka.onnx", size: 500_000, source: "models-fasttext-onnx" },
          kk: { file: "fasttext.kk.onnx", size: 500_000, source: "models-fasttext-onnx" },
          km: { file: "fasttext.km.onnx", size: 500_000, source: "models-fasttext-onnx" },
          kn: { file: "fasttext.kn.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ko: { file: "fasttext.ko.onnx", size: 500_000, source: "models-fasttext-onnx" },
          krc: { file: "fasttext.krc.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ku: { file: "fasttext.ku.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ky: { file: "fasttext.ky.onnx", size: 500_000, source: "models-fasttext-onnx" },
          la: { file: "fasttext.la.onnx", size: 500_000, source: "models-fasttext-onnx" },
          lad: { file: "fasttext.lad.onnx", size: 500_000, source: "models-fasttext-onnx" },
          lb: { file: "fasttext.lb.onnx", size: 500_000, source: "models-fasttext-onnx" },
          lmo: { file: "fasttext.lmo.onnx", size: 500_000, source: "models-fasttext-onnx" },
          lt: { file: "fasttext.lt.onnx", size: 500_000, source: "models-fasttext-onnx" },
          lv: { file: "fasttext.lv.onnx", size: 500_000, source: "models-fasttext-onnx" },
          mai: { file: "fasttext.mai.onnx", size: 500_000, source: "models-fasttext-onnx" },
          mg: { file: "fasttext.mg.onnx", size: 500_000, source: "models-fasttext-onnx" },
          mhr: { file: "fasttext.mhr.onnx", size: 500_000, source: "models-fasttext-onnx" },
          min: { file: "fasttext.min.onnx", size: 500_000, source: "models-fasttext-onnx" },
          mk: { file: "fasttext.mk.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ml: { file: "fasttext.ml.onnx", size: 500_000, source: "models-fasttext-onnx" },
          mn: { file: "fasttext.mn.onnx", size: 500_000, source: "models-fasttext-onnx" },
          mr: { file: "fasttext.mr.onnx", size: 500_000, source: "models-fasttext-onnx" },
          mrj: { file: "fasttext.mrj.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ms: { file: "fasttext.ms.onnx", size: 500_000, source: "models-fasttext-onnx" },
          mt: { file: "fasttext.mt.onnx", size: 500_000, source: "models-fasttext-onnx" },
          mwl: { file: "fasttext.mwl.onnx", size: 500_000, source: "models-fasttext-onnx" },
          my: { file: "fasttext.my.onnx", size: 500_000, source: "models-fasttext-onnx" },
          myv: { file: "fasttext.myv.onnx", size: 500_000, source: "models-fasttext-onnx" },
          mzn: { file: "fasttext.mzn.onnx", size: 500_000, source: "models-fasttext-onnx" },
          nah: { file: "fasttext.nah.onnx", size: 500_000, source: "models-fasttext-onnx" },
          nap: { file: "fasttext.nap.onnx", size: 500_000, source: "models-fasttext-onnx" },
          nds: { file: "fasttext.nds.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ne: { file: "fasttext.ne.onnx", size: 500_000, source: "models-fasttext-onnx" },
          new: { file: "fasttext.new.onnx", size: 500_000, source: "models-fasttext-onnx" },
          nl: { file: "fasttext.nl.onnx", size: 500_000, source: "models-fasttext-onnx" },
          nn: { file: "fasttext.nn.onnx", size: 500_000, source: "models-fasttext-onnx" },
          no: { file: "fasttext.no.onnx", size: 500_000, source: "models-fasttext-onnx" },
          oc: { file: "fasttext.oc.onnx", size: 500_000, source: "models-fasttext-onnx" },
          or: { file: "fasttext.or.onnx", size: 500_000, source: "models-fasttext-onnx" },
          os: { file: "fasttext.os.onnx", size: 500_000, source: "models-fasttext-onnx" },
          pa: { file: "fasttext.pa.onnx", size: 500_000, source: "models-fasttext-onnx" },
          pam: { file: "fasttext.pam.onnx", size: 500_000, source: "models-fasttext-onnx" },
          pfl: { file: "fasttext.pfl.onnx", size: 500_000, source: "models-fasttext-onnx" },
          pms: { file: "fasttext.pms.onnx", size: 500_000, source: "models-fasttext-onnx" },
          pnb: { file: "fasttext.pnb.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ps: { file: "fasttext.ps.onnx", size: 500_000, source: "models-fasttext-onnx" },
          pt: { file: "fasttext.pt.onnx", size: 500_000, source: "models-fasttext-onnx" },
          qu: { file: "fasttext.qu.onnx", size: 500_000, source: "models-fasttext-onnx" },
          rm: { file: "fasttext.rm.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ro: { file: "fasttext.ro.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ru: { file: "fasttext.ru.onnx", size: 500_000, source: "models-fasttext-onnx" },
          rue: { file: "fasttext.rue.onnx", size: 500_000, source: "models-fasttext-onnx" },
          sa: { file: "fasttext.sa.onnx", size: 500_000, source: "models-fasttext-onnx" },
          sah: { file: "fasttext.sah.onnx", size: 500_000, source: "models-fasttext-onnx" },
          scn: { file: "fasttext.scn.onnx", size: 500_000, source: "models-fasttext-onnx" },
          sco: { file: "fasttext.sco.onnx", size: 500_000, source: "models-fasttext-onnx" },
          sd: { file: "fasttext.sd.onnx", size: 500_000, source: "models-fasttext-onnx" },
          sh: { file: "fasttext.sh.onnx", size: 500_000, source: "models-fasttext-onnx" },
          si: { file: "fasttext.si.onnx", size: 500_000, source: "models-fasttext-onnx" },
          sk: { file: "fasttext.sk.onnx", size: 500_000, source: "models-fasttext-onnx" },
          sl: { file: "fasttext.sl.onnx", size: 500_000, source: "models-fasttext-onnx" },
          so: { file: "fasttext.so.onnx", size: 500_000, source: "models-fasttext-onnx" },
          sq: { file: "fasttext.sq.onnx", size: 500_000, source: "models-fasttext-onnx" },
          sr: { file: "fasttext.sr.onnx", size: 500_000, source: "models-fasttext-onnx" },
          su: { file: "fasttext.su.onnx", size: 500_000, source: "models-fasttext-onnx" },
          sv: { file: "fasttext.sv.onnx", size: 500_000, source: "models-fasttext-onnx" },
          sw: { file: "fasttext.sw.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ta: { file: "fasttext.ta.onnx", size: 500_000, source: "models-fasttext-onnx" },
          te: { file: "fasttext.te.onnx", size: 500_000, source: "models-fasttext-onnx" },
          tg: { file: "fasttext.tg.onnx", size: 500_000, source: "models-fasttext-onnx" },
          th: { file: "fasttext.th.onnx", size: 500_000, source: "models-fasttext-onnx" },
          tk: { file: "fasttext.tk.onnx", size: 500_000, source: "models-fasttext-onnx" },
          tl: { file: "fasttext.tl.onnx", size: 500_000, source: "models-fasttext-onnx" },
          tr: { file: "fasttext.tr.onnx", size: 500_000, source: "models-fasttext-onnx" },
          tt: { file: "fasttext.tt.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ty: { file: "fasttext.ty.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ug: { file: "fasttext.ug.onnx", size: 500_000, source: "models-fasttext-onnx" },
          uk: { file: "fasttext.uk.onnx", size: 500_000, source: "models-fasttext-onnx" },
          ur: { file: "fasttext.ur.onnx", size: 500_000, source: "models-fasttext-onnx" },
          uz: { file: "fasttext.uz.onnx", size: 500_000, source: "models-fasttext-onnx" },
          vec: { file: "fasttext.vec.onnx", size: 500_000, source: "models-fasttext-onnx" },
          vi: { file: "fasttext.vi.onnx", size: 500_000, source: "models-fasttext-onnx" },
          vls: { file: "fasttext.vls.onnx", size: 500_000, source: "models-fasttext-onnx" },
          vo: { file: "fasttext.vo.onnx", size: 500_000, source: "models-fasttext-onnx" },
          wa: { file: "fasttext.wa.onnx", size: 500_000, source: "models-fasttext-onnx" },
          war: { file: "fasttext.war.onnx", size: 500_000, source: "models-fasttext-onnx" },
          wuu: { file: "fasttext.wuu.onnx", size: 500_000, source: "models-fasttext-onnx" },
          xh: { file: "fasttext.xh.onnx", size: 500_000, source: "models-fasttext-onnx" },
          yi: { file: "fasttext.yi.onnx", size: 500_000, source: "models-fasttext-onnx" },
          yo: { file: "fasttext.yo.onnx", size: 500_000, source: "models-fasttext-onnx" },
          zh: { file: "fasttext.zh.onnx", size: 500_000, source: "models-fasttext-onnx" },
          'zh-classical': { file: "fasttext.zh-classical.onnx", size: 500_000, source: "models-fasttext-onnx" }
        }
      }.freeze

      # Get or download FastText model for a language.
      #
      # @param language_code [String] ISO 639-1 language code
      # @param force_download [Boolean] Force re-download
      # @return [String, nil] Path to downloaded .vec file
      def get_fasttext_model(language_code, force_download: false)
        resource_id = "#{language_code}:fasttext"
        result = get(resource_id, force_download: force_download)

        result&.dig(:model_path)
      end

      # Get or download ONNX model for a language.
      #
      # @param language_code [String] ISO 639-1 language code
      # @param force_download [Boolean] Force re-download
      # @return [String, nil] Path to downloaded .onnx file
      def get_onnx_model(language_code, force_download: false)
        resource_id = "#{language_code}:onnx"
        result = get(resource_id, force_download: force_download)

        result&.dig(:model_path)
      end

      # Get available model types for a language.
      #
      # @param language_code [String] ISO 639-1 language code
      # @return [Array<Symbol>] Available model types (:fasttext, :onnx)
      def available_models_for(language_code)
        lang = language_code.to_sym
        types = []
        types << :fasttext if AVAILABLE_MODELS[:fasttext][lang]
        types << :onnx if AVAILABLE_MODELS[:onnx][lang]
        types
      end

      # Get model info for a language and type.
      #
      # @param language_code [String] ISO 639-1 language code
      # @param model_type [Symbol] Model type (:fasttext, :onnx)
      # @return [Hash, nil] Model info or nil if not available
      def model_info(language_code, model_type)
        AVAILABLE_MODELS.dig(model_type, language_code.to_sym)
      end

      # List all available models across all languages.
      #
      # @return [Hash] Mapping of language to available model types
      def all_available_models
        AVAILABLE_MODELS
      end

      # Check if a resource type is supported.
      #
      # @param resource_id [String] The resource identifier (e.g., "en:fasttext")
      # @return [Boolean] True if supported
      def supports_resource?(resource_id)
        parts = resource_id.split(":")
        return false unless parts.size == 2

        language, type = parts
        AVAILABLE_MODELS[type.to_sym]&.key?(language.to_sym)
      end

      # List all cached resources.
      #
      # @return [Array<String>] List of cached resource identifiers
      def cached_resources
        Dir.glob(File.join(@cache_path, "**", "metadata.json")).map do |path|
          relative = Pathname.new(path).relative_path_to(Pathname.new(@cache_path))
          parts = relative.to_s.split("/")
          "#{parts[0]}:#{parts[2]}" # language:model_type
        end.uniq
      end

      protected

      # Download a specific resource (implements abstract method).
      #
      # @param resource_id [String] The resource identifier
      # @param dest_path [String] Destination directory
      # @return [Hash] Downloaded model info
      def download_resource(resource_id, dest_path)
        language = extract_language(resource_id)
        type = extract_type(resource_id)
        return nil unless language && type

        model_info = AVAILABLE_MODELS[type.to_sym][language.to_sym]
        return nil unless model_info

        FileUtils.mkdir_p(dest_path)

        filename = model_info[:file]

        # Handle ONNX with try-download-first approach
        if type == "onnx"
          download_or_convert_onnx(language, dest_path, filename)
        else
          # Handle FastText download (existing logic)
          url = model_url(language, type, filename)

          # Remove .gz extension for final storage (we decompress gzip files)
          final_filename = filename.sub('.gz', '')
          model_file = File.join(dest_path, final_filename)

          # Download (and decompress if needed)
          if url.end_with?('.gz')
            download_and_decompress(url, model_file)
          else
            download_file(url, model_file)
          end

          # Save metadata
          metadata = build_model_metadata(language, type, final_filename, url, model_file)
          write_metadata(File.join(dest_path, "metadata.json"), metadata)

          { model_path: model_file, metadata: metadata }
        end
      end

      # Load cached resource data (implements abstract method).
      #
      # @param resource_id [String] The resource identifier
      # @return [Hash, nil] Loaded model info
      def load_cached(resource_id)
        language = extract_language(resource_id)
        type = extract_type(resource_id)
        return nil unless language && type

        model_info = AVAILABLE_MODELS[type.to_sym][language.to_sym]
        return nil unless model_info

        metadata_path = metadata_path_for(resource_id)
        return nil unless File.exist?(metadata_path)

        metadata = read_metadata(metadata_path)
        return nil unless metadata

        # For .gz files, the decompressed version is stored without .gz extension
        filename = model_info[:file].sub('.gz', '')
        model_file = File.join(resource_dir_for(resource_id), filename)

        return nil unless File.exist?(model_file)

        { model_path: model_file, metadata: metadata }
      end

      # Get metadata file path for a resource.
      #
      # @param resource_id [String] The resource identifier
      # @return [String] Metadata file path
      def metadata_path_for(resource_id)
        language = extract_language(resource_id)
        type = extract_type(resource_id)
        File.join(@cache_path, language, "models", type, "metadata.json")
      end

      # Get resource directory path.
      #
      # @param resource_id [String] The resource identifier
      # @return [String] Resource directory path
      def resource_dir_for(resource_id)
        language = extract_language(resource_id)
        type = extract_type(resource_id)
        File.join(@cache_path, language, "models", type)
      end

      # Check if all resource files exist.
      #
      # @param resource_id [String] The resource identifier
      # @return [Boolean] True if all files exist
      def resource_files_exist?(resource_id)
        language = extract_language(resource_id)
        type = extract_type(resource_id)
        return false unless language && type

        model_info = AVAILABLE_MODELS[type.to_sym][language.to_sym]
        return false unless model_info

        # For .gz files, check the decompressed version
        filename = model_info[:file].sub('.gz', '')
        model_file = File.join(resource_dir_for(resource_id), filename)
        File.exist?(model_file) && File.size(model_file).positive?
      end

      private

      # Build metadata hash for a model.
      #
      # @param language [String] Language code
      # @param type [String] Model type
      # @param filename [String] Model filename
      # @param url [String] Download URL
      # @param model_file [String] Path to downloaded model file
      # @return [Hash] Metadata hash
      def build_model_metadata(language, type, filename, url, model_file)
        {
          version: Time.now.utc.iso8601,
          url: url,
          language: language,
          type: type,
          file: filename,
          checksum: Digest::SHA256.file(model_file).hexdigest,
          cached_at: Time.now.utc.iso8601
        }
      end

      # Get URL for a model file.
      #
      # @param language [String] Language code
      # @param type [String] Model type
      # @param filename [String] Model filename
      # @return [String, nil] Download URL
      def model_url(language, type, filename)
        case type
        when "fasttext"
          # Download from FastText CDN (Facebook Research)
          # https://fasttext.cc/docs/en/english-vectors.html
          "https://dl.fbaipublicfiles.com/fasttext/vectors-crawl/#{filename}"
        when "onnx"
          # Download from models-fasttext-onnx GitHub repository
          # Files are at: models-fasttext-onnx/{pin}/models/{lang}/{filename}
          "#{models_url_base}/models/#{language}/#{filename}"
        else
          "#{@url_base}/dictionaries/main/#{language}/models/#{type}/#{filename}"
        end
      end

      # URL for the vocab.json sibling file. The conversion script ships
      # vocabularies alongside the .onnx so OnnxModel.from_file can resolve
      # word→index without re-parsing the FastText .vec.
      #
      # @param language [String] Language code
      # @return [String]
      def vocab_url(language)
        "#{models_url_base}/models/#{language}/fasttext.#{language}.vocab.json"
      end

      def models_url_base
        @models_url_base ||= begin
          cfg = Kotoshu::Configuration.instance
          "#{cfg.models_url.chomp('/').sub(%r{/main\z}, '')}/#{cfg.models_pin}"
        end
      end

      # Download and decompress gzip file.
      #
      # @param url [String] URL to gzip file
      # @param dest_path [String] Destination path (without .gz)
      def download_and_decompress(url, dest_path)
        # Download to temporary file first
        temp_gz = "#{dest_path}.gz"

        puts "  Downloading from #{url.split('/').last}..." if $VERBOSE

        downloaded_bytes = 0
        URI.open(url, open_timeout: 30, read_timeout: 300) do |uri|
          File.open(temp_gz, 'wb') do |f|
            downloaded_bytes = f.write(uri.read)
          end
        end

        puts "  Downloaded: #{(downloaded_bytes.to_f / 1024 / 1024).round(2)} MB" if $VERBOSE

        # Verify the download succeeded
        unless File.exist?(temp_gz) && File.size(temp_gz).positive?
          raise "Download failed: #{temp_gz} is empty or missing"
        end

        puts "  Decompressing..." if $VERBOSE

        # Remove existing file if present (handles partial downloads)
        File.delete(dest_path) if File.exist?(dest_path)

        # Decompress gzip with streaming
        File.open(temp_gz, 'rb') do |gz_file|
          Zlib::GzipReader.wrap(gz_file) do |gzip|
            # Stream in chunks to avoid memory issues with large files
            File.open(dest_path, 'wb') do |out_file|
              chunk_size = 65_536 # 64KB chunks
              while (chunk = gzip.read(chunk_size))
                out_file.write(chunk)
                # Print progress every 10MB
                if $VERBOSE && out_file.pos % (10 * 1024 * 1024) < chunk_size
                  puts "    Decompressed: #{(out_file.pos.to_f / 1024 / 1024).round(1)} MB..."
                end
              end
            end
          end
        end

        # Verify the decompression succeeded
        unless File.exist?(dest_path) && File.size(dest_path).positive?
          raise "Decompression failed: #{dest_path} is empty or missing"
        end

        # Clean up gz file
        File.delete(temp_gz)

        puts "  ✓ Downloaded and decompressed" if $VERBOSE
      end

      # Convert FastText .vec file to ONNX format.
      #
      # @param language [String] Language code
      # @param dest_path [String] Destination directory
      # @param onnx_filename [String] Output ONNX filename
      # @return [Hash] Converted model info
      def convert_to_onnx(language, dest_path, onnx_filename)
        puts "Converting FastText to ONNX for #{language}..." if $VERBOSE

        # First, ensure we have the FastText .vec file
        fasttext_resource_id = "#{language}:fasttext"
        fasttext_result = get(fasttext_resource_id, force_download: false)

        unless fasttext_result
          raise "Failed to get FastText model for #{language} needed for ONNX conversion"
        end

        vec_file = fasttext_result[:model_path]

        # Verify the .vec file exists
        unless File.exist?(vec_file)
          raise "FastText .vec file not found: #{vec_file}"
        end

        # Output ONNX file path
        onnx_file = File.join(dest_path, onnx_filename)

        # Get the conversion script path
        script_path = File.expand_path('../scripts/fasttext_to_onnx.py', __dir__)

        unless File.exist?(script_path)
          raise "ONNX conversion script not found: #{script_path}"
        end

        # Build conversion command
        # Use --vocab-size to limit vocabulary size and reduce conversion time
        vocab_size = fasttext_result.dig(:metadata, "vocab_size")&.to_i || 100_000

        cmd = [
          'python3',
          script_path,
          vec_file,
          onnx_file,
          '--vocab-size', vocab_size.to_s
        ]

        puts "  Running conversion: #{shell_join(cmd)}" if $VERBOSE

        # Run conversion
        require 'open3'
        stdout, stderr, status = Open3.capture3(*cmd)

        unless status.success?
          raise "ONNX conversion failed:\n#{stdout}\n#{stderr}"
        end

        puts stdout if $VERBOSE

        # Build metadata for the ONNX file
        metadata = {
          version: Time.now.utc.iso8601,
          url: "converted:#{vec_file}",
          language: language,
          type: "onnx",
          file: onnx_filename,
          checksum: Digest::SHA256.file(onnx_file).hexdigest,
          cached_at: Time.now.utc.iso8601,
          source_model: File.basename(vec_file),
          conversion_method: "fasttext_to_onnx.py"
        }

        # Save metadata
        write_metadata(File.join(dest_path, "metadata.json"), metadata)

        puts "  ✓ ONNX conversion complete" if $VERBOSE

        { model_path: onnx_file, metadata: metadata }
      end

      # Try to download ONNX from GitHub, fall back to conversion if download fails.
      #
      # @param language [String] Language code
      # @param dest_path [String] Destination directory
      # @param onnx_filename [String] ONNX filename
      # @return [Hash] Downloaded or converted model info
      def download_or_convert_onnx(language, dest_path, onnx_filename)
        url = model_url(language, "onnx", onnx_filename)
        onnx_file = File.join(dest_path, onnx_filename)

        puts "  Attempting download from GitHub..." if $VERBOSE

        # Try downloading from GitHub first
        begin
          download_file(url, onnx_file)

          # Verify the downloaded file
          unless File.exist?(onnx_file) && File.size(onnx_file).positive?
            raise "Download failed: empty file"
          end

          # Pull the matching vocab.json so OnnxModel.from_file can resolve
          # word→index without re-parsing the source FastText .vec.
          begin
            download_file(vocab_url(language),
                          File.join(dest_path, "fasttext.#{language}.vocab.json"))
          rescue StandardError => e
            warn "  vocab.json unavailable for #{language}: #{e.message}" if $VERBOSE
          end

          puts "  ✓ Downloaded from GitHub" if $VERBOSE

          # Build metadata for downloaded file
          metadata = {
            version: Time.now.utc.iso8601,
            url: url,
            language: language,
            type: "onnx",
            file: onnx_filename,
            checksum: Digest::SHA256.file(onnx_file).hexdigest,
            cached_at: Time.now.utc.iso8601,
            source: "github"
          }

          # Save metadata
          write_metadata(File.join(dest_path, "metadata.json"), metadata)

          { model_path: onnx_file, metadata: metadata }
        rescue StandardError => e
          puts "  GitHub download failed: #{e.message}" if $VERBOSE
          puts "  Falling back to local conversion..." if $VERBOSE

          # Remove partial download if any
          File.delete(onnx_file) if File.exist?(onnx_file)

          # Fall back to local conversion
          convert_to_onnx(language, dest_path, onnx_filename)
        end
      end

      # Join shell command arguments safely (for display purposes).
      #
      # @param args [Array<String>] Command arguments
      # @return [String] Joined command string
      def shell_join(args)
        args.map { |a| a =~ /\s/ ? "'#{a}'" : a }.join(' ')
      end

      # Default cache path: $XDG_CACHE_HOME/kotoshu/models
      #
      # @return [String] Default cache path
      def default_cache_path
        File.join(Kotoshu::Paths.cache_path, "models")
      end

      # Default cache TTL (30 days for models).
      #
      # @return [Integer] Default TTL in seconds
      def default_cache_ttl
        2_592_000 # 30 days
      end
    end
  end
end
