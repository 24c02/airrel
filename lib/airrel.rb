# frozen_string_literal: true

require_relative "airrel/version"

module Airrel
  class Error < StandardError; end

  autoload :Relation, "airrel/relation"
  autoload :WhereClause, "airrel/where_clause"
  autoload :FormulaBuilder, "airrel/formula_builder"
end
