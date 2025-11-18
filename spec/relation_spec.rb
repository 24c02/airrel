# frozen_string_literal: true

require "spec_helper"

RSpec.describe Airrel::Relation do
  # Mock table class
  let(:table_class) do
    Class.new do
      def self.records(**params)
        @last_params = params
        []
      end

      def self.last_params
        @last_params
      end

      def self.find(id)
        { "id" => id }
      end
    end
  end

  let(:relation) { described_class.new(table_class) }

  describe "#where" do
    it "returns a new relation" do
      new_relation = relation.where(role: "admin")
      expect(new_relation).to be_a(described_class)
      expect(new_relation).not_to eq(relation)
    end

    it "is immutable" do
      original = relation.where(role: "admin")
      original.where(active: true)
      
      expect(original.to_airtable[:filter]).to eq("{role} = 'admin'")
    end

    it "chains multiple conditions with AND" do
      result = relation.where(role: "admin").where(active: true)
      expect(result.to_airtable[:filter]).to eq("AND({role} = 'admin', {active} = TRUE())")
    end

    it "accepts raw formula strings" do
      result = relation.where("{Age} > 18")
      expect(result.to_airtable[:filter]).to eq("{Age} > 18")
    end

    it "combines hash and string conditions" do
      result = relation.where(role: "admin").where("{Age} > 18")
      expect(result.to_airtable[:filter]).to eq("AND({role} = 'admin', {Age} > 18)")
    end
  end

  describe "#order" do
    it "returns a new relation" do
      new_relation = relation.order(:name)
      expect(new_relation).not_to eq(relation)
    end

    it "accepts a symbol" do
      result = relation.order(:name)
      expect(result.to_airtable[:sort]).to eq([{ field: "name", direction: "asc" }])
    end

    it "accepts a hash" do
      result = relation.order(name: :desc, age: :asc)
      expect(result.to_airtable[:sort]).to eq([
        { field: "name", direction: "desc" },
        { field: "age", direction: "asc" }
      ])
    end

    it "chains multiple order calls" do
      result = relation.order(:name).order(:age)
      expect(result.to_airtable[:sort]).to eq([
        { field: "name", direction: "asc" },
        { field: "age", direction: "asc" }
      ])
    end

    it "normalizes direction strings" do
      result = relation.order(name: "desc")
      expect(result.to_airtable[:sort]).to eq([{ field: "name", direction: "desc" }])
    end
  end

  describe "#limit" do
    it "sets max_records" do
      result = relation.limit(10)
      expect(result.to_airtable[:max_records]).to eq(10)
    end

    it "returns a new relation" do
      new_relation = relation.limit(10)
      expect(new_relation).not_to eq(relation)
    end

    it "replaces previous limit" do
      result = relation.limit(10).limit(5)
      expect(result.to_airtable[:max_records]).to eq(5)
    end
  end

  describe "#offset" do
    it "sets offset parameter" do
      result = relation.offset(20)
      expect(result.to_airtable[:offset]).to eq(20)
    end
  end

  describe "lazy loading" do
    it "doesn't execute query when building relation" do
      expect(table_class).not_to receive(:records)
      relation.where(role: "admin").order(:name).limit(10)
    end

    it "executes query when iterating" do
      expect(table_class).to receive(:records).and_return([])
      relation.where(role: "admin").each { |r| r }
    end

    it "executes query when calling to_a" do
      expect(table_class).to receive(:records).and_return([])
      relation.where(role: "admin").to_a
    end

    it "only executes once" do
      expect(table_class).to receive(:records).once.and_return([])
      rel = relation.where(role: "admin")
      rel.to_a
      rel.to_a # second call shouldn't trigger another query
    end

    it "can be reloaded" do
      expect(table_class).to receive(:records).twice.and_return([])
      rel = relation.where(role: "admin")
      rel.to_a
      rel.reload
    end
  end

  describe "#first" do
    it "loads records and returns first" do
      allow(table_class).to receive(:records).and_return([1, 2, 3])
      expect(relation.first).to eq(1)
    end

    it "accepts a limit argument" do
      expect(table_class).to receive(:records) do |**params|
        expect(params[:max_records]).to eq(3)
        [1, 2, 3]
      end
      
      expect(relation.first(3)).to eq([1, 2, 3])
    end
  end

  describe "#last" do
    it "requires an order to be specified" do
      expect {
        relation.last
      }.to raise_error(ArgumentError, /last requires an order/)
    end

    it "reverses order and gets first" do
      expect(table_class).to receive(:records) do |**params|
        # check that order was reversed
        expect(params[:sort]).to eq([{ field: "name", direction: "desc" }])
        [1, 2, 3]
      end
      
      result = relation.order(:name).last
      expect(result).to eq(1) # first item of the reversed array
    end

    it "works with limit" do
      expect(table_class).to receive(:records) do |**params|
        expect(params[:max_records]).to eq(3)
        expect(params[:sort]).to eq([{ field: "name", direction: "desc" }])
        [1, 2, 3]
      end

      result = relation.order(:name).last(3)
      expect(result).to eq([3, 2, 1]) # reversed
    end
  end

  describe "#find_by" do
    it "returns first matching record" do
      allow(table_class).to receive(:records).and_return([{ id: 1 }])
      result = relation.find_by(email: "test@example.com")
      expect(result).to eq({ id: 1 })
    end

    it "returns nil if not found" do
      allow(table_class).to receive(:records).and_return([])
      result = relation.find_by(email: "test@example.com")
      expect(result).to be_nil
    end
  end

  describe "#find_by!" do
    it "raises if not found" do
      allow(table_class).to receive(:records).and_return([])
      expect {
        relation.find_by!(email: "test@example.com")
      }.to raise_error(StandardError) # would be RecordNotFoundError in norairrecord context
    end
  end

  describe "#count" do
    it "loads and counts records" do
      allow(table_class).to receive(:records).and_return([1, 2, 3])
      expect(relation.count).to eq(3)
    end
  end

  describe "#to_airtable_params" do
    it "builds complete params hash" do
      result = relation
        .where(role: "admin")
        .where(active: true)
        .order(name: :asc)
        .limit(10)
        .offset(5)
        .to_airtable

      expect(result).to eq({
        filter: "AND({role} = 'admin', {active} = TRUE())",
        sort: [{ field: "name", direction: "asc" }],
        max_records: 10,
        offset: 5
      })
    end

    it "omits empty params" do
      result = relation.to_airtable
      expect(result).to eq({})
    end
  end

  describe "enumerable" do
    before do
      allow(table_class).to receive(:records).and_return([1, 2, 3])
    end

    it "can be mapped" do
      result = relation.map { |x| x * 2 }
      expect(result).to eq([2, 4, 6])
    end

    it "can be filtered" do
      result = relation.select { |x| x > 1 }
      expect(result).to eq([2, 3])
    end

    it "supports any?" do
      expect(relation.any?).to be true
    end

    it "supports empty?" do
      expect(relation.empty?).to be false
    end
  end
end
