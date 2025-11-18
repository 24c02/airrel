# frozen_string_literal: true

module Airrel
  module FormulaBuilder
    extend self

    def hash_to_formula(conditions, field_mappings = {})
      formulas = conditions.map do |key, value|
        field_name = field_mappings[key.to_s] || key.to_s
        build_predicate(field_name, value)
      end

      formulas.size == 1 ? formulas.first : "AND(#{formulas.join(", ")})"
    end

    def build_predicate(field, value)
      case value
      when nil
        "{#{field}} = BLANK()"
      when true
        "{#{field}} = TRUE()"
      when false
        "{#{field}} = FALSE()"
      when String
        "{#{field}} = #{escape_string(value)}"
      when Numeric
        "{#{field}} = #{value}"
      when Range
        if value.exclude_end?
          "AND({#{field}} >= #{escape_value(value.begin)}, {#{field}} < #{escape_value(value.end)})"
        else
          "AND({#{field}} >= #{escape_value(value.begin)}, {#{field}} <= #{escape_value(value.end)})"
        end
      when Array
        # IN query - use OR
        or_conditions = value.map { |v| build_predicate(field, v) }
        "OR(#{or_conditions.join(", ")})"
      else
        # fallback - convert to string and escape
        "{#{field}} = #{escape_string(value.to_s)}"
      end
    end

    # escape a string value for use in airtable formulas
    # airtable uses backslash escaping: \ escapes the next character
    # so we need to escape backslashes first, then quotes
    def escape_string(str)
      # escape backslashes first (\ -> \\), then quotes (' -> \', " -> \")
      escaped = str.to_s.gsub("\\", "\\\\\\\\").gsub(/['"]/, '\\\\\0')
      "'#{escaped}'"
    end

    # escape any value (delegates to appropriate method)
    def escape_value(value)
      case value
      when String
        escape_string(value)
      when Numeric
        value.to_s
      when nil
        "BLANK()"
      when true
        "TRUE()"
      when false
        "FALSE()"
      else
        escape_string(value.to_s)
      end
    end

    # helper methods for building formulas programmatically

    def all(*formulas) = "AND(#{formulas.join(", ")})"

    def any(*formulas) = "OR(#{formulas.join(", ")})"

    def none(formula) = "NOT(#{formula})"

    def eq(field, value) = build_predicate(field, value)

    def neq(field, value) = none(eq(field, value))

    def gt(field, value) = "{#{field}} > #{value}"

    def gte(field, value) = "{#{field}} >= #{value}"

    def lt(field, value) = "{#{field}} < #{value}"

    def lte(field, value) = "{#{field}} <= #{value}"

    def blank(field) = "{#{field}} = BLANK()"

    def present(field) = none(blank(field))

    def find(field, search_string) = "FIND(#{escape_string(search_string)}, {#{field}})"

    def search(field, search_string) = "SEARCH(#{escape_string(search_string)}, {#{field}})"

    # for multi-select fields (checks if array contains value)
    def contains(field, value) = "FIND(#{escape_string(value.to_s)}, {#{field}})"

    # check if multi-select contains ANY of the values
    def contains_any(field, *values)
      formulas = values.map { |v| contains(field, v) }
      formulas.size == 1 ? formulas.first : any(*formulas)
    end

    # check if multi-select contains ALL of the values
    def contains_all(field, *values)
      formulas = values.map { |v| contains(field, v) }
      formulas.size == 1 ? formulas.first : all(*formulas)
    end
  end
end
