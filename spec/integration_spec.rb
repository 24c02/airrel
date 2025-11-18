# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Airrel integration" do
  let(:table_class) do
    Class.new do
      def self.records(**params)
        @params = params
        []
      end

      def self.last_params
        @params
      end
    end
  end

  it "builds complex queries" do
    relation = Airrel::Relation.new(table_class)
      .where(role: ["admin", "moderator"])
      .where(active: true)
      .where("{Age} >= 18")
      .order(name: :asc, created_at: :desc)
      .limit(20)
      .offset(10)

    relation.to_a

    params = table_class.last_params
    expect(params[:filter]).to eq(
      "AND(OR({role} = 'admin', {role} = 'moderator'), {active} = TRUE(), {Age} >= 18)"
    )
    expect(params[:sort]).to eq([
      { field: "name", direction: "asc" },
      { field: "created_at", direction: "desc" }
    ])
    expect(params[:max_records]).to eq(20)
    expect(params[:offset]).to eq(10)
  end

  it "handles edge cases in string values" do
    relation = Airrel::Relation.new(table_class)
      .where(
        name: "O'Reilly",
        quote: 'Say "hello"',
        both: %q{It's a "test"},
        malicious: "'; DROP TABLE users; --"
      )

    relation.to_a

    filter = table_class.last_params[:filter]
    expect(filter).to include("'O\\'Reilly'")
    expect(filter).to include('Say \\"hello\\"')
    expect(filter).to include(%q{It\\'s a \\"test\\"})
    expect(filter).to include("'\\'; DROP TABLE users; --'")
  end

  it "combines hash and raw formulas naturally" do
    relation = Airrel::Relation.new(table_class)
      .where(status: "active")
      .where("LEN({Description}) > 100")
      .where(priority: [1, 2, 3])

    relation.to_a

    filter = table_class.last_params[:filter]
    expect(filter).to eq(
      "AND({status} = 'active', LEN({Description}) > 100, OR({priority} = 1, {priority} = 2, {priority} = 3))"
    )
  end

  it "supports formula builder helpers" do
    relation = Airrel::Relation.new(table_class)
      .where(Airrel::FormulaBuilder.all(
        Airrel::FormulaBuilder.gte("Age", 18),
        Airrel::FormulaBuilder.lte("Age", 65),
        Airrel::FormulaBuilder.present("Email")
      ))

    relation.to_a

    filter = table_class.last_params[:filter]
    expect(filter).to eq("AND({Age} >= 18, {Age} <= 65, NOT({Email} = BLANK()))")
  end

  it "handles nil/blank conditions correctly" do
    relation = Airrel::Relation.new(table_class)
      .where(email: nil, deleted_at: nil)

    relation.to_a

    filter = table_class.last_params[:filter]
    expect(filter).to eq("AND({email} = BLANK(), {deleted_at} = BLANK())")
  end

  it "handles range queries" do
    relation = Airrel::Relation.new(table_class)
      .where(age: 18..65, score: 0...100)

    relation.to_a

    filter = table_class.last_params[:filter]
    expect(filter).to eq(
      "AND(AND({age} >= 18, {age} <= 65), AND({score} >= 0, {score} < 100))"
    )
  end
end
