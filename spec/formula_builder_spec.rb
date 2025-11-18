# frozen_string_literal: true

require "spec_helper"

RSpec.describe Airrel::FormulaBuilder do
  describe ".hash_to_formula" do
    it "builds formula from single condition" do
      result = described_class.hash_to_formula(role: "admin")
      expect(result).to eq("{role} = 'admin'")
    end

    it "builds AND formula from multiple conditions" do
      result = described_class.hash_to_formula(role: "admin", active: true)
      expect(result).to eq("AND({role} = 'admin', {active} = TRUE())")
    end

    it "uses field mappings" do
      mappings = { "first_name" => "First Name", "email" => "Email Address" }
      result = described_class.hash_to_formula({ first_name: "Alice" }, mappings)
      expect(result).to eq("{First Name} = 'Alice'")
    end
  end

  describe ".build_predicate" do
    it "handles nil values" do
      expect(described_class.build_predicate("email", nil)).to eq("{email} = BLANK()")
    end

    it "handles true values" do
      expect(described_class.build_predicate("active", true)).to eq("{active} = TRUE()")
    end

    it "handles false values" do
      expect(described_class.build_predicate("active", false)).to eq("{active} = FALSE()")
    end

    it "handles string values" do
      expect(described_class.build_predicate("name", "Alice")).to eq("{name} = 'Alice'")
    end

    it "handles numeric values" do
      expect(described_class.build_predicate("age", 25)).to eq("{age} = 25")
      expect(described_class.build_predicate("price", 19.99)).to eq("{price} = 19.99")
    end

    it "handles inclusive ranges" do
      result = described_class.build_predicate("age", 18..65)
      expect(result).to eq("AND({age} >= 18, {age} <= 65)")
    end

    it "handles exclusive ranges" do
      result = described_class.build_predicate("age", 18...65)
      expect(result).to eq("AND({age} >= 18, {age} < 65)")
    end

    it "handles string ranges" do
      result = described_class.build_predicate("name", "A".."Z")
      expect(result).to eq("AND({name} >= 'A', {name} <= 'Z')")
    end

    it "handles arrays as OR conditions" do
      result = described_class.build_predicate("role", %w[admin moderator guest])
      expect(result).to eq("OR({role} = 'admin', {role} = 'moderator', {role} = 'guest')")
    end

    it "handles arrays with different types" do
      result = described_class.build_predicate("status", [1, "active", nil])
      expect(result).to eq("OR({status} = 1, {status} = 'active', {status} = BLANK())")
    end
  end

  describe ".escape_string" do
    it "wraps string in single quotes" do
      expect(described_class.escape_string("hello")).to eq("'hello'")
    end

    it "escapes single quotes with backslash" do
      expect(described_class.escape_string("O'Reilly")).to eq("'O\\'Reilly'")
    end

    it "escapes double quotes with backslash" do
      expect(described_class.escape_string('Say "hello"')).to eq("'Say \\\"hello\\\"'")
    end

    it "escapes both single and double quotes" do
      expect(described_class.escape_string(%q(It's a "test"))).to eq(%q('It\\'s a \\"test\\"'))
    end

    it "handles empty strings" do
      expect(described_class.escape_string("")).to eq("''")
    end

    it "escapes backslashes" do
      expect(described_class.escape_string("C:\\path")).to eq("'C:\\\\path'")
    end

    it "escapes backslash at end of string" do
      expect(described_class.escape_string("path\\")).to eq("'path\\\\'")
    end

    it "escapes backslash before quote" do
      expect(described_class.escape_string("test\\'s")).to eq("'test\\\\\\'s'")
    end

    it "handles unicode" do
      expect(described_class.escape_string("café ☕")).to eq("'café ☕'")
    end

    it "handles SQL injection attempts" do
      malicious = "'; DROP TABLE users; --"
      expect(described_class.escape_string(malicious)).to eq("'\\'; DROP TABLE users; --'")
    end

    it "handles formula injection attempts" do
      malicious = "'; OR(TRUE())"
      expect(described_class.escape_string(malicious)).to eq("'\\'; OR(TRUE())'")
    end
  end

  describe ".escape_value" do
    it "escapes strings" do
      expect(described_class.escape_value("test")).to eq("'test'")
    end

    it "handles numbers" do
      expect(described_class.escape_value(42)).to eq("42")
      expect(described_class.escape_value(3.14)).to eq("3.14")
    end

    it "handles nil" do
      expect(described_class.escape_value(nil)).to eq("BLANK()")
    end

    it "handles booleans" do
      expect(described_class.escape_value(true)).to eq("TRUE()")
      expect(described_class.escape_value(false)).to eq("FALSE()")
    end
  end

  describe "helper methods" do
    describe ".all" do
      it "joins formulas with AND" do
        expect(described_class.all("{a} = 1", "{b} = 2")).to eq("AND({a} = 1, {b} = 2)")
      end
    end

    describe ".any" do
      it "joins formulas with OR" do
        expect(described_class.any("{a} = 1", "{b} = 2")).to eq("OR({a} = 1, {b} = 2)")
      end
    end

    describe ".none" do
      it "wraps formula in NOT" do
        expect(described_class.none("{a} = 1")).to eq("NOT({a} = 1)")
      end
    end

    describe ".eq" do
      it "builds equality predicate" do
        expect(described_class.eq("name", "Alice")).to eq("{name} = 'Alice'")
      end
    end

    describe ".neq" do
      it "builds not-equal predicate" do
        expect(described_class.neq("name", "Alice")).to eq("NOT({name} = 'Alice')")
      end
    end

    describe ".gt" do
      it "builds greater-than predicate" do
        expect(described_class.gt("age", 18)).to eq("{age} > 18")
      end
    end

    describe ".gte" do
      it "builds greater-than-or-equal predicate" do
        expect(described_class.gte("age", 18)).to eq("{age} >= 18")
      end
    end

    describe ".lt" do
      it "builds less-than predicate" do
        expect(described_class.lt("age", 65)).to eq("{age} < 65")
      end
    end

    describe ".lte" do
      it "builds less-than-or-equal predicate" do
        expect(described_class.lte("age", 65)).to eq("{age} <= 65")
      end
    end

    describe ".blank" do
      it "builds BLANK() check" do
        expect(described_class.blank("email")).to eq("{email} = BLANK()")
      end
    end

    describe ".present" do
      it "builds NOT BLANK() check" do
        expect(described_class.present("email")).to eq("NOT({email} = BLANK())")
      end
    end

    describe ".find" do
      it "builds FIND() function call" do
        expect(described_class.find("name", "Alice")).to eq("FIND('Alice', {name})")
      end

      it "escapes search string" do
        expect(described_class.find("name", "O'Reilly")).to eq("FIND('O\\'Reilly', {name})")
      end
    end

    describe ".search" do
      it "builds SEARCH() function call" do
        expect(described_class.search("tags", "important")).to eq("SEARCH('important', {tags})")
      end

      it "escapes search string" do
        expect(described_class.search("tags", "it's")).to eq("SEARCH('it\\'s', {tags})")
      end
    end
  end
end
