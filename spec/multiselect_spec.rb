# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Multi-select field helpers" do
  let(:builder) { Airrel::FormulaBuilder }

  describe ".contains" do
    it "builds FIND for single value" do
      expect(builder.contains("Roles", "admin")).to eq("FIND('admin', {Roles})")
    end

    it "escapes the value" do
      expect(builder.contains("Tags", "it's important")).to eq("FIND('it\\'s important', {Tags})")
    end

    it "works with numbers" do
      expect(builder.contains("IDs", 123)).to eq("FIND('123', {IDs})")
    end
  end

  describe ".contains_any" do
    it "checks if field contains any of the values" do
      result = builder.contains_any("Roles", "admin", "moderator")
      expect(result).to eq("OR(FIND('admin', {Roles}), FIND('moderator', {Roles}))")
    end

    it "works with single value" do
      result = builder.contains_any("Tags", "important")
      expect(result).to eq("FIND('important', {Tags})")
    end
  end

  describe ".contains_all" do
    it "checks if field contains all of the values" do
      result = builder.contains_all("Roles", "admin", "moderator")
      expect(result).to eq("AND(FIND('admin', {Roles}), FIND('moderator', {Roles}))")
    end
  end

  describe "integration with relations" do
    let(:table_class) do
      Class.new do
        def self.records(**params)
          @last_params = params
          []
        end

        class << self
          attr_reader :last_params
        end
      end
    end

    it "works in where clauses" do
      relation = Airrel::Relation.new(table_class)
                                 .where(builder.contains("Roles", "admin"))

      relation.to_a

      expect(table_class.last_params[:filter]).to eq("FIND('admin', {Roles})")
    end

    it "chains with other conditions" do
      relation = Airrel::Relation.new(table_class)
                                 .where(active: true)
                                 .where(builder.contains("Roles", "admin"))

      relation.to_a

      filter = table_class.last_params[:filter]
      expect(filter).to eq("AND({active} = TRUE(), FIND('admin', {Roles}))")
    end

    it "combines with contains_any" do
      relation = Airrel::Relation.new(table_class)
                                 .where(builder.contains_any("Roles", "admin", "moderator", "guest"))

      relation.to_a

      filter = table_class.last_params[:filter]
      expect(filter).to include("OR(")
      expect(filter).to include("FIND('admin', {Roles})")
      expect(filter).to include("FIND('moderator', {Roles})")
    end
  end
end
