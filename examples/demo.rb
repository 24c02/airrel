#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "airrel"

# fake norairrecord table for testing
class User
  def self.records(**params)
    puts "Would call Airtable API with:"
    puts params.inspect
    []
  end
end

# basic chaining
puts "=== basic chaining ==="
relation = Airrel::Relation.new(User)
                           .where(role: "admin")
                           .where(active: true)
                           .order(created_at: :desc)
                           .limit(10)

puts relation.to_airtable
puts

# hash to formula conversion
puts "=== hash to formula ==="
puts Airrel::FormulaBuilder.hash_to_formula(email: "test@example.com", age: 25)
puts Airrel::FormulaBuilder.hash_to_formula(age: 18..65)
puts Airrel::FormulaBuilder.hash_to_formula(role: %w[admin moderator])
puts Airrel::FormulaBuilder.hash_to_formula(deleted_at: nil)
puts

# formula builder helpers
puts "=== formula builder helpers ==="
include Airrel::FormulaBuilder

puts eq("Name", "Alice")
puts gt("Age", 18)
puts all(eq("Role", "admin"), present("Email"))
puts any(eq("Role", "admin"), eq("Role", "moderator"))
puts

# lazy execution
puts "=== lazy execution ==="
query = Airrel::Relation.new(User).where(role: "admin")
puts "Query built (no API call yet)"
puts "Iterating now..."
query.each { |u| puts u }
