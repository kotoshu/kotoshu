# frozen_string_literal: true

module Kotoshu
  module Results
    # Result pattern for explicit error handling.
    #
    # Provides a type-safe way to handle operations that can fail
    # without using exceptions. Based on functional programming patterns.
    #
    # @example Using Success
    #   result = Result::Success.new("value")
    #   result.success?  # => true
    #   result.value     # => "value"
    #
    # @example Using Failure
    #   result = Result::Failure.new(error)
    #   result.failure?  # => true
    #   result.error      # => the error
    #
    # @example Chaining operations
    #   result = Result::Success.new(5)
    #     .and_then { |v| Success.new(v * 2) }  # Only called if success
    #     .or_else { |e| Success.new(0) }        # Only called if failure
    module Result
      # Base result class.
      #
      # @abstract
      class Base
        # Check if result is successful.
        #
        # @return [Boolean] True if successful
        def success?
          is_a?(Success)
        end

        # Check if result is a failure.
        #
        # @return [Boolean] True if failed
        def failure?
          is_a?(Failure)
        end

        # Map the value if successful.
        #
        # @yield [value] The wrapped value
        # @return [Result::Success, Result::Failure] Mapped result
        def map
          return self if failure?

          Success.new(yield value)
        rescue StandardError => e
          Failure.new(e)
        end

        # Chain operations if successful.
        #
        # @yield [value] The wrapped value
        # @return [Result::Success, Result::Failure] Chained result
        def and_then
          return self if failure?

          result = yield value

          # Ensure we get a Result back
          result.is_a?(Base) ? result : Success.new(result)
        rescue StandardError => e
          Failure.new(e)
        end

        # Recover from failure.
        #
        # @yield [error] The wrapped error
        # @return [Result::Success, Result::Failure] Recovered result
        def or_else
          return self if success?

          result = yield error

          # Ensure we get a Result back
          result.is_a?(Base) ? result : Success.new(result)
        end

        # Unwrap the value or raise error.
        #
        # @return [Object] The wrapped value
        # @raise [Error] The wrapped error if this is a Failure
        def unwrap
          return value if success?

          raise error
        end

        # Get the wrapped value (nil for Failure).
        #
        # @return [Object, nil] The wrapped value or nil
        def value
          raise NotImplementedError
        end

        # Get the wrapped error (nil for Success).
        #
        # @return [StandardError, nil] The wrapped error or nil
        def error
          raise NotImplementedError
        end
      end

      # Represents a successful operation.
      #
      class Success < Base
        # @return [Object] The wrapped value
        attr_reader :value

        # Create a new Success result.
        #
        # @param value [Object] The wrapped value
        def initialize(value)
          @value = value
        end

        # Get the error (always nil for Success).
        #
        # @return [nil] Always nil
        def error
          nil
        end
      end

      # Represents a failed operation.
      #
      class Failure < Base
        # @return [StandardError] The wrapped error
        attr_reader :error

        # Create a new Failure result.
        #
        # @param error [StandardError] The wrapped error
        def initialize(error)
          @error = error
        end

        # Map does nothing for Failure.
        #
        # @return [Failure] Self
        def map
          self
        end

        # and_then does nothing for Failure.
        #
        # @return [Failure] Self
        def and_then
          self
        end

        # Get the value (always nil for Failure).
        #
        # @return [nil] Always nil
        def value
          nil
        end
      end
    end
  end
end
