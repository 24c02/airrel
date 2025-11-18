# frozen_string_literal: true

require "spec_helper"

RSpec.describe Airrel::WhereClause do
  describe "#merge" do
    it "merges hash conditions" do
      clause = described_class.new
      merged = clause.merge(role: "admin")
      expect(merged.predicates).to eq(["{role} = 'admin'"])
    end

    it "merges string conditions" do
      clause = described_class.new
      merged = clause.merge("{Age} > 18")
      expect(merged.predicates).to eq(["{Age} > 18"])
    end

    it "merges array conditions" do
      clause = described_class.new
      merged = clause.merge(["{a} = 1", "{b} = 2"])
      expect(merged.predicates).to eq(["{a} = 1", "{b} = 2"])
    end

    it "chains multiple merges" do
      clause = described_class.new
      merged = clause.merge(role: "admin").merge(active: true)
      expect(merged.predicates).to eq([
                                        "{role} = 'admin'",
                                        "{active} = TRUE()"
                                      ])
    end

    it "is immutable" do
      original = described_class.new
      merged = original.merge(role: "admin")

      expect(original.predicates).to be_empty
      expect(merged.predicates).to eq(["{role} = 'admin'"])
    end
  end

  describe "#any?" do
    it "returns false for empty clause" do
      clause = described_class.new
      expect(clause.any?).to be false
    end

    it "returns true for non-empty clause" do
      clause = described_class.new(["{a} = 1"])
      expect(clause.any?).to be true
    end
  end

  describe "#to_airtable_formula" do
    it "returns nil for empty clause" do
      clause = described_class.new
      expect(clause.to_airtable_formula).to be_nil
    end

    it "returns single predicate as-is" do
      clause = described_class.new(["{role} = 'admin'"])
      expect(clause.to_airtable_formula).to eq("{role} = 'admin'")
    end

    it "wraps multiple predicates in AND" do
      clause = described_class.new(["{role} = 'admin'", "{active} = TRUE()"])
      expect(clause.to_airtable_formula).to eq("AND({role} = 'admin', {active} = TRUE())")
    end

    it "handles many predicates" do
      clause = described_class.new(["{a} = 1", "{b} = 2", "{c} = 3"])
      expect(clause.to_airtable_formula).to eq("AND({a} = 1, {b} = 2, {c} = 3)")
    end
  end
end
