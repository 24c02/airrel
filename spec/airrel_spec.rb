# frozen_string_literal: true

RSpec.describe Airrel do
  it "has a version number" do
    expect(Airrel::VERSION).not_to be nil
  end

  it "provides chainable query interface" do
    expect(Airrel::Relation).to be_a(Class)
    expect(Airrel::FormulaBuilder).to be_a(Module)
  end
end
