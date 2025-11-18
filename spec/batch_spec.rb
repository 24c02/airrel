# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Batch processing" do
  let(:table_class) do
    Class.new do
      @call_count = 0
      
      def self.records(**params)
        @call_count ||= 0
        offset = params[:offset] || 0
        limit = params[:max_records] || 100
        
        # simulate 250 total records
        all_records = (1..250).to_a
        result = all_records[offset, limit] || []
        
        @call_count += 1
        result
      end
      
      def self.call_count
        @call_count
      end
      
      def self.reset_count
        @call_count = 0
      end
    end
  end

  let(:relation) { Airrel::Relation.new(table_class) }

  before do
    table_class.reset_count
  end

  describe "#find_each" do
    it "yields records one at a time" do
      yielded = []
      relation.find_each(batch_size: 100) { |record| yielded << record }
      
      expect(yielded.size).to eq(250)
      expect(yielded.first).to eq(1)
      expect(yielded.last).to eq(250)
    end

    it "loads in batches" do
      relation.find_each(batch_size: 100) { |r| r }
      
      # should make 3 calls (100, 100, 50)
      expect(table_class.call_count).to eq(3)
    end

    it "respects existing where clauses" do
      # note: our mock doesn't actually filter, but params should have filter
      called_with = nil
      allow(table_class).to receive(:records) do |**params|
        called_with ||= params
        []
      end
      
      relation.where(role: "admin").find_each { |r| r }
      
      expect(called_with[:filter]).to eq("{role} = 'admin'")
    end
  end

  describe "#find_in_batches" do
    it "yields batches of records" do
      batches = []
      relation.find_in_batches(batch_size: 100) { |batch| batches << batch }
      
      expect(batches.size).to eq(3)
      expect(batches[0].size).to eq(100)
      expect(batches[1].size).to eq(100)
      expect(batches[2].size).to eq(50)
    end

    it "handles small result sets" do
      # mock to return only 50 records
      allow(table_class).to receive(:records) do |**params|
        (1..50).to_a
      end
      
      batches = []
      relation.find_in_batches(batch_size: 100) { |batch| batches << batch }
      
      expect(batches.size).to eq(1)
      expect(batches[0].size).to eq(50)
    end
  end
end
