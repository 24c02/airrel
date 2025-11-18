# frozen_string_literal: true

module Airrel
  class WhereClause
    attr_reader :predicates

    def initialize(predicates = [])
      @predicates = predicates
    end

    def merge(conditions)
      new_predicates = case conditions
                       when Hash
                         [FormulaBuilder.hash_to_formula(conditions)]
                       when String
                         [conditions]
                       when Array
                         conditions
                       else
                         [conditions.to_s]
                       end

      WhereClause.new(@predicates + new_predicates)
    end

    def any?
      @predicates.any?
    end

    def to_airtable_formula
      return nil if @predicates.empty?
      return @predicates.first if @predicates.size == 1

      "AND(#{@predicates.join(', ')})"
    end

    def inspect
      @predicates.inspect
    end
  end
end
