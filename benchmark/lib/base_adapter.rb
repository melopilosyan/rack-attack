# frozen_string_literal: true

module Rack
  class Attack
    module Adapters
      class Base
        attr_reader :backend

        class << self
          def build(backend)
            define_with(backend)
            new(backend)
          end

          def define_with(backend)
            allow_redefinition_of_with_for_tests

            class_exec do
              if backend.respond_to?(:with)
                def with
                  @backend.with { |client| yield client }
                rescue rescue_from_error
                  0
                end
              else
                def with
                  yield @backend
                rescue rescue_from_error
                  0
                end
              end
            end
          end

          private

          def allow_redefinition_of_with_for_tests
            return unless method_defined?(:with)

            ancestors.reverse_each do |klass|
              klass.remove_method :with if klass.method_defined?(:with)
            end
          end
        end

        def initialize(backend)
          @backend = backend
        end

        private

        # Define this method on your adapter, returning the error class to be rescued from,
        # if it's using the +with+ method.
        def rescue_from_error
          raise NotImplementedError
        end
      end
    end
  end
end
